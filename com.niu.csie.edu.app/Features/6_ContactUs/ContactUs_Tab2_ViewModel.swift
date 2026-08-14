// https://forms.gle/VtD6fdu5b2j82uL37

import SwiftUI
import Foundation
import Combine
import DeviceKit // 取得裝置型號名稱



@MainActor
final class ContactUs_Tab2_ViewModel: ObservableObject {
    
    @Published var BugType: String = ""
    @Published var BugDescription: String = ""
    // 新增勾選狀態
    @Published var isSendingDeviceInfoChecked: Bool = false
    // 新增 toast 控制
    @Published var showToast: Bool = false
    @Published var showSubmissionFailedToast: Bool = false
    // --- 用於處理全域狀態導向 ---
    weak var appState: AppState?
    
    private let bugReportFormResponseURL = "https://docs.google.com/forms/d/1ZxakDZyKm1FyMeKixnKFxXOPa0y7DqAeK2H_pWAuXPY/formResponse"
    private let entryBugType = "entry.1504346357"
    private let entryBugDescription = "entry.333978968"
    private let entryDeviceInfo = "entry.1452100371"
    private let entryAppInfo = "entry.2095589085"
    
    // 取得 App & Device 資訊
    var appInfo: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "App版本：\(version)\nApp版本號：\(build)"
    }
        
    var deviceInfo: String {
        let device = Device.current
        // `device.description` 會回傳可讀名稱，如 "iPhone 15 Pro Max"
        let deviceName = device.description
        let system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        return "裝置型號：\(deviceName)\n系統版本：\(system)"
    }
    
    // 送出
    func submitBugReport() {
        let bugType = normalizeLineBreaks(BugType)
        let bugDescription = normalizeLineBreaks(BugDescription)
        
        guard !(bugType.isEmpty && bugDescription.isEmpty) else {
            showToast = true
            return
        }
        
        var parameters: [(String, String)] = [
            (entryBugType, bugType),
            (entryBugDescription, bugDescription),
            (entryAppInfo, appInfo)
        ]
        
        // 傳送設備資訊：維持 iOS 原本可取得的內容，不擴充 Android 欄位。
        if isSendingDeviceInfoChecked {
            parameters.append((entryDeviceInfo, deviceInfo))
        }
        
        guard let url = URL(string: bugReportFormResponseURL),
              let body = formURLEncodedBody(parameters) else {
            showSubmissionFailedToast = true
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        Task { [weak self] in
            guard let self else { return }
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    self.showSubmissionFailedToast = true
                    return
                }
                
                self.appState?.navigate(
                    to: .home,
                    withToast: LocalizedStringKey("Submit_Successful")
                )
            } catch {
                self.showSubmissionFailedToast = true
            }
        }
    }
    
    private func normalizeLineBreaks(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
    
    private func formURLEncodedBody(_ parameters: [(String, String)]) -> Data? {
        var components = URLComponents()
        components.queryItems = parameters.map {
            URLQueryItem(name: $0.0, value: $0.1)
        }
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}
