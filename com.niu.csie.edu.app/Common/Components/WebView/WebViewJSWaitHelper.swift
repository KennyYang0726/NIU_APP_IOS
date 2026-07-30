import Foundation


@MainActor
extension WebView_Provider {

    public func evaluateJSAsync(_ js: String) async -> String? {
        await withCheckedContinuation { continuation in
            self.evaluateJS(js) { value in
                continuation.resume(returning: value)
            }
        }
    }

    public func waitUntilJS(
        _ js: String,
        timeout: TimeInterval = 5.0,
        intervalNanoseconds: UInt64 = 100_000_000
    ) async -> Bool {
        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            let value = await evaluateJSAsync(js)?
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if value == "true" || value == "1" {
                return true
            }

            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }

        return false
    }
}

