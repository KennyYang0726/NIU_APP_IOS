import SwiftUI



@MainActor
final class SSOKeepAliveService: ObservableObject {
    private var task: Task<Void, Never>?
    private let interval: UInt64 = 5 * 60 * 1_000_000_000  // 5 分鐘

    func start(with session: SessionManager) {
        guard task == nil else { return }

        task = Task { [weak session] in
            guard let session else { return }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }

                // 只做檢查；距離 exp 小於 5 分鐘才會真的 refresh。
                session.refreshSSOSessionIfNeeded()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
