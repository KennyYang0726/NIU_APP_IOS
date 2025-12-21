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
                    // 通常是被 cancel，直接跳出迴圈就好
                    break
                }
                // 再保險一次，避免剛 sleep 完就被 cancel
                guard !Task.isCancelled else { break }
                session.refreshSSOID()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
