import Foundation
import SwiftUI
import UIKit



final class QRCodeScanViewModel: ObservableObject {
    
    @Published var showToast = false
    @Published var isHandlingScan = false
    
    // 合法前綴
    private let ccsysPrefix = "https://ccsys.niu.edu.tw/MvcTeam/Act/Apply/"
    private let googleFormsPrefix = "https://docs.google.com/forms/"
    private let formsShortPrefix = "https://forms.gle/"
    
    func handleScannedCode(
        _ code: String,
        onValidCCSYS: @escaping (String) -> Void
    ) {
        guard !isHandlingScan else { return }
        isHandlingScan = true
        
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            showInvalidToast()
            return
        }
        
        // 1. Google Forms / forms.gle -> 直接開瀏覽器
        if trimmed.hasPrefix(googleFormsPrefix) || trimmed.hasPrefix(formsShortPrefix) {
            guard let url = URL(string: trimmed) else {
                showInvalidToast()
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                UIApplication.shared.open(url) { success in
                    if success {
                        self?.isHandlingScan = false
                    } else {
                        self?.showInvalidToast()
                    }
                }
            }
            return
        }
        
        // 2. CCSYS -> 回傳給上層
        if trimmed.hasPrefix(ccsysPrefix) {
            onValidCCSYS(trimmed)
            isHandlingScan = false
            return
        }
        
        // 3. 其他 -> 非法
        showInvalidToast()
    }
    
    private func showInvalidToast() {
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isHandlingScan = false
        }
    }
}
