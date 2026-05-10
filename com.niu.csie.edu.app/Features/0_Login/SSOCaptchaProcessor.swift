//
//  CaptchaProcessorSSO.swift
//  Features/0_Login
//
//  對應 Android: Captcha_Process_SSO.java
//  改用 Apple Vision Framework OCR (VNRecognizeTextRequest)
//  功能：
//   - 前處理（干擾色替換 ±21 容忍度 → 灰階化）
//   - Vision 文字辨識（只取英數字）
//   - 後處理：0/6 修正、常見字元替換、僅保留數字
//   - 回傳：成功時 6 位數字字串，否則 nil
//   - Log.d 對應 print（使用 [Captcha]）
//   - iOS 16+
//

import UIKit
import Vision



public final class SSOCaptchaProcessor {
    public static let shared = SSOCaptchaProcessor()
    private init() {}

    // OCR 單次結果
    private struct OCRPassResult {
        let modeName: String
        let raw: String
        let fixed: String
        let mapped: String
        let digitsOnly: String
        let confidenceSum: Float
    }

    // 前處理模式
    private enum PreprocessMode {
        case grayscaleOnly
        case binary(threshold: Int)

        var debugName: String {
            switch self {
            case .grayscaleOnly:
                return "gray"
            case .binary(let threshold):
                return "binary@\(threshold)"
            }
        }
    }

    // Swift: 只回傳六位數字；其餘細節印 log
    public func recognize(from image: UIImage, completion: @escaping (String?) -> Void) {
        // 改成背景執行，避免連跑 2~3 次 OCR 時卡住主執行緒
        DispatchQueue.global(qos: .userInitiated).async {
            // 同一張 captcha 跑多種前處理：
            // 1) 保留灰階細節
            // 2) 偏低 threshold
            // 3) 偏高 threshold
            //
            // 這樣會比單次 OCR 稍慢，但通常可以明顯降低「OCR 錯誤 → 整頁 reload」的機率，
            // 對整體登入體感多半是划算的。
            let modes: [PreprocessMode] = [
                .grayscaleOnly,
                .binary(threshold: 142),
                .binary(threshold: 162)
            ]

            var passResults: [OCRPassResult] = []

            for mode in modes {
                guard let pre = self.preprocess(image: image, mode: mode) else {
                    print("[Captcha][\(mode.debugName)] preprocess failed")
                    continue
                }

                if let result = self.performOCR(on: pre, modeName: mode.debugName) {
                    print("[Captcha][\(mode.debugName)] raw=\(result.raw), fixed=\(result.fixed), mapped=\(result.mapped), digitsOnly=\(result.digitsOnly), conf=\(result.confidenceSum)")
                    passResults.append(result)
                } else {
                    print("[Captcha][\(mode.debugName)] OCR result empty or failed")
                }
            }

            let best = self.selectBestCandidate(from: passResults)
            completion(best)
        }
    }

    // MARK: - Vision OCR 單次執行
    private func performOCR(on image: UIImage, modeName: String) -> OCRPassResult? {
        guard let cgImage = image.cgImage else {
            print("[Captcha][\(modeName)] cgImage nil")
            return nil
        }

        var outResult: OCRPassResult?
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { [weak self] request, error in
            defer { semaphore.signal() }

            guard let self = self else { return }

            if let error = error {
                print("[Captcha][\(modeName)] OCR error: \(error.localizedDescription)")
                return
            }

            guard let results = request.results as? [VNRecognizedTextObservation], !results.isEmpty else {
                print("[Captcha][\(modeName)] OCR result empty")
                return
            }

            // Vision 的觀察結果順序不一定穩，保險起見用 x 座標排序
            let sorted = results.sorted { $0.boundingBox.minX < $1.boundingBox.minX }

            var raw = ""
            var elements: [(text: String, frame: CGRect)] = []
            var confidenceSum: Float = 0

            for obs in sorted {
                guard let candidate = obs.topCandidates(1).first else { continue }
                let text = candidate.string
                raw.append(text)
                elements.append((text, obs.boundingBox))
                confidenceSum += candidate.confidence
            }

            // 3) 0/6 修正
            let fixed = self.fixZeroSix(on: image, elements: elements)

            // 4) 字元替換
            let mapped = self.mapChars(fixed)

            // 5) 僅保留數字
            let digitsOnly = mapped.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

            outResult = OCRPassResult(
                modeName: modeName,
                raw: raw,
                fixed: fixed,
                mapped: mapped,
                digitsOnly: digitsOnly,
                confidenceSum: confidenceSum
            )
        }

        // 限制為英文與數字 (Vision 自動辨識語言會比較慢)
        request.recognitionLanguages = ["en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        // 只想抓 captcha 那種相對顯眼的字，不想被過多雜點影響
        request.minimumTextHeight = 0.22

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            semaphore.wait()
        } catch {
            print("[Captcha][\(modeName)] perform OCR error: \(error.localizedDescription)")
            return nil
        }

        return outResult
    }

    // MARK: - 多結果投票 / 挑選
    private func selectBestCandidate(from results: [OCRPassResult]) -> String? {
        guard !results.isEmpty else { return nil }

        let exactSix = results.filter { $0.digitsOnly.count == 6 }

        // 先看有沒有完整六碼
        if !exactSix.isEmpty {
            // 先做投票：同樣的 6 碼出現次數越多越可信
            var grouped: [String: [OCRPassResult]] = [:]
            for item in exactSix {
                grouped[item.digitsOnly, default: []].append(item)
            }

            // 依據：
            // 1. 出現次數多者優先
            // 2. confidenceSum 較高者優先
            // 3. mapped 中非數字越少者優先（理論上 exactSix 已經都是數字，但仍保留排序依據）
            let best = grouped.max { lhs, rhs in
                let lCount = lhs.value.count
                let rCount = rhs.value.count
                if lCount != rCount { return lCount < rCount }

                let lConf = lhs.value.map(\.confidenceSum).reduce(0, +)
                let rConf = rhs.value.map(\.confidenceSum).reduce(0, +)
                if lConf != rConf { return lConf < rConf }

                let lNoise = lhs.value.map { self.nonDigitCount(in: $0.mapped) }.reduce(0, +)
                let rNoise = rhs.value.map { self.nonDigitCount(in: $0.mapped) }.reduce(0, +)
                return lNoise > rNoise
            }

            if let picked = best?.key {
                let sources = best?.value.map(\.modeName).joined(separator: ",") ?? ""
                print("[Captcha] picked six-digits=\(picked) from [\(sources)]")
                return picked
            }
        }

        // 沒有任何完整六碼時，仍印出最佳候選供 debug，但回傳 nil 讓外層 retry
        let fallback = results.max { lhs, rhs in
            if lhs.digitsOnly.count != rhs.digitsOnly.count {
                return lhs.digitsOnly.count < rhs.digitsOnly.count
            }
            if lhs.confidenceSum != rhs.confidenceSum {
                return lhs.confidenceSum < rhs.confidenceSum
            }
            return self.nonDigitCount(in: lhs.mapped) > self.nonDigitCount(in: rhs.mapped)
        }

        if let fallback {
            print("[Captcha] best incomplete candidate mode=\(fallback.modeName), digitsOnly=\(fallback.digitsOnly)")
        }

        return nil
    }

    private func nonDigitCount(in s: String) -> Int {
        s.reduce(0) { partial, ch in
            partial + (ch.isNumber ? 0 : 1)
        }
    }

    // MARK: - 前處理：干擾色替換 + 灰階化
    private func preprocess(image: UIImage, mode: PreprocessMode) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let width = cg.width
        let height = cg.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var buffer = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let drawOK: Bool = buffer.withUnsafeMutableBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return false }
            guard let ctx = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawOK else { return nil }

        // 目標干擾色（與 Android 相同）
        let tol = 21
        let targets: [(Int, Int, Int)] = [
            (0x97, 0x8C, 0x89), // #978C89
            (0x99, 0x99, 0x99), // #999999
            (0xAC, 0xAC, 0xAC), // #ACACAC
            (0xAD, 0xAD, 0xAD), // #ADADAD
            (0xAF, 0xAE, 0xAD), // #AFAEAD
            (0xB0, 0xB0, 0xB0)  // #B0B0B0
        ]

        @inline(__always) func isNearTarget(_ r: Int, _ g: Int, _ b: Int) -> Bool {
            for t in targets {
                if abs(t.0 - r) <= tol && abs(t.1 - g) <= tol && abs(t.2 - b) <= tol { return true }
            }
            return false
        }

        // 干擾色替換成偏亮底色，讓後續灰階 / 二值化更穩定
        let replR = UInt8(0xF2), replG = UInt8(0xF3), replB = UInt8(0xF5)

        for y in 0..<height {
            let row = y * bytesPerRow
            var x = 0
            while x < width {
                let i = row + x * bytesPerPixel
                let r = Int(buffer[i + 0])
                let g = Int(buffer[i + 1])
                let b = Int(buffer[i + 2])

                if isNearTarget(r, g, b) {
                    buffer[i + 0] = replR
                    buffer[i + 1] = replG
                    buffer[i + 2] = replB
                }
                
                
                // 灰階
                let lum = (77 * Int(buffer[i + 0]) + 150 * Int(buffer[i + 1]) + 29 * Int(buffer[i + 2])) >> 8
                let gray = UInt8(max(0, min(255, lum)))

                
                switch mode {
                case .grayscaleOnly:
                    buffer[i + 0] = gray
                    buffer[i + 1] = gray
                    buffer[i + 2] = gray

                case .binary(let threshold):
                    // 加入二值化，讓前景 / 背景對比更明確
                    // 不同 threshold 會對不同 captcha 更有利，所以同圖跑多個版本
                    let bw: UInt8 = gray > threshold ? 255 : 0
                    buffer[i + 0] = bw
                    buffer[i + 1] = bw
                    buffer[i + 2] = bw
                }

                x += 1
            }
        }

        let outCG: CGImage? = buffer.withUnsafeMutableBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return nil }
            guard let outCtx = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return outCtx.makeImage()
        }
        guard let cgimg = outCG else { return nil }
        return UIImage(cgImage: cgimg, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - 0/6 修正：
    private func fixZeroSix(on image: UIImage, elements: [(text: String, frame: CGRect)]) -> String {
        var out = ""
        for (t, frame) in elements {
            var c = t
            if t == "6" || t == "G" {
                if let crop = crop(image: image, rect: frame) {
                    if looksLikeZero(crop) { c = "0" }
                }
            }
            out.append(c)
        }
        return out
    }

    private func crop(image: UIImage, rect: CGRect) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let r = CGRect(
            x: rect.origin.x * CGFloat(cg.width),
            y: (1 - rect.origin.y - rect.height) * CGFloat(cg.height),
            width: rect.width * CGFloat(cg.width),
            height: rect.height * CGFloat(cg.height)
        )
        guard let cut = cg.cropping(to: r.integral) else { return nil }
        return UIImage(cgImage: cut)
    }

    private func looksLikeZero(_ img: UIImage) -> Bool {
        guard let cg = img.cgImage else { return false }
        let w = cg.width, h = cg.height
        let bytesPerPixel = 4, bytesPerRow = bytesPerPixel * w
        var buf = Data(count: h * bytesPerRow)

        guard buf.withUnsafeMutableBytes({ ptr -> Bool in
            guard let ctx = CGContext(
                data: ptr.baseAddress,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }) else { return false }

        let black: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in
            Int(r) < 64 && Int(g) < 64 && Int(b) < 64
        }

        let topH = max(1, h / 2)
        let leftW = max(1, w / 2)
        var lt = 0, rt = 0, ltAll = 0, rtAll = 0

        buf.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let p = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

            for y in 0..<topH {
                let row = p.advanced(by: y * bytesPerRow)

                for x in 0..<leftW {
                    let px = row.advanced(by: x * bytesPerPixel)
                    if black(px[0], px[1], px[2]) { lt += 1 }
                    ltAll += 1
                }

                for x in leftW..<w {
                    let px = row.advanced(by: x * bytesPerPixel)
                    if black(px[0], px[1], px[2]) { rt += 1 }
                    rtAll += 1
                }
            }
        }

        let rLT = Double(lt) / Double(max(1, ltAll))
        let rRT = Double(rt) / Double(max(1, rtAll))

        // 原本邏輯：利用左右上半區的黑點分布不對稱，區分 0 / 6
        let isZero = (rLT > 0.08 && rRT < 0.06) || abs(rLT - rRT) > 0.06
        return isZero
    }

    // MARK: - 字元替換規則
    private func mapChars(_ s: String) -> String {
        var out = ""
        for ch in s {
            let c: Character
            switch ch {
            case "O", "o", "G", "D", "Q", "e", "@":
                c = "0"
            case "A", "a", "I", "l", "|", "!", "/", "\\":
                c = "1"
            case "Z", "z":
                c = "2"
            case "S", "s", "$":
                c = "5"
            case "b":
                c = "6"
            case "T", "?", ">":
                c = "7"
            case "B", "E":
                c = "8"
            case "q", "g":
                c = "9"
            default:
                c = ch
            }
            out.append(c)
        }
        return out
    }
}
