import SwiftUI
import Foundation
import Combine



@MainActor
final class ContactUs_Tab1_ViewModel: ObservableObject {
    
    @Published var Content: String = ""
    @Published var ContactInfo: String = ""
    // 新增勾選狀態
    @Published var isRegisteredSendChecked: Bool = false
    // 新增 toast 控制
    @Published var showToast: Bool = false
    @Published var showSubmissionFailedToast: Bool = false
    // --- 全域注射 ---
    private var appSettings: AppSettings?
    private var loginRepo: LoginRepository?
    // --- 用於處理全域狀態導向 ---
    weak var appState: AppState?
    
    private let feedbackFormResponseURL = "https://docs.google.com/forms/d/14hzv6f5nPTJB4cGjFShqHneiAQBeIlxxQXmJsruZJ-g/formResponse"
    private let entryContent = "entry.831595071"
    private let entryContactInfo = "entry.1325961611"
    private let entryRegistered = "entry.911616058"

    
    // 讓 View 注入 AppSettings 和 LoginRepository
    func configure(appSettings: AppSettings, loginRepo: LoginRepository) {
        self.appSettings = appSettings
        self.loginRepo = loginRepo
    }
    
    // 送出
    func submitFeedback() {
        let content = normalizeLineBreaks(Content)
        
        guard !content.isEmpty else {
            showToast = true
            return
        }
        
        var parameters: [(String, String)] = [
            (entryContent, content)
        ]
        
        let contactInfo = normalizeLineBreaks(ContactInfo)
        if contactInfo.count >= 3 {
            parameters.append((entryContactInfo, contactInfo))
        }
        
        if isRegisteredSendChecked {
            let username = loginRepo?.loadCredentials()?.username ?? "取得學號失敗"
            let name = appSettings?.name ?? "取得姓名失敗"
            parameters.append((entryRegistered, "\(username)\n\(name)"))
        }
        
        guard let url = URL(string: feedbackFormResponseURL),
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
