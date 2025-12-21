import SwiftUI


// 使用者從左邊緣滑動時
//  → 如果 webView.canGoBack = true → WebView 後退
//  → 如果不能 → 才 pop 回上一頁
struct NavigationSwipeHijacker: UIViewControllerRepresentable {
    let handleSwipe: () -> Bool   // return true = interrupt pop, false = allow pop

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()

        DispatchQueue.main.async {
            if let nav = vc.navigationController,
               let gesture = nav.interactivePopGestureRecognizer {
                gesture.isEnabled = true
                gesture.delegate = context.coordinator
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(handleSwipe: handleSwipe)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let handleSwipe: () -> Bool

        init(handleSwipe: @escaping () -> Bool) {
            self.handleSwipe = handleSwipe
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // true = 要攔截，不讓 pop
            // false = 不攔截，讓 NavigationStack pop
            return !handleSwipe()
        }
    }
}
