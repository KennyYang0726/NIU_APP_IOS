import UIKit
import WebKit


@MainActor
enum ClassScheduleSnapshotSharer {

    private static var activeRenderers: [OffscreenHTMLSnapshotRenderer] = []

    static func share(
        webProvider: WebView_Provider,
        studentID: String,
        name: String,
        isDarkMode: Bool
    ) {
        webProvider.evaluateJS("document.documentElement.outerHTML") { html in
            guard let html else {
                return
            }

            let title = String(
                format: NSLocalizedString("ClassScheduleShareTitle", comment: ""),
                studentID,
                name
            )
            let textColor = isDarkMode ? "#e0e0e0" : "#111111"
            let backgroundColor = isDarkMode ? "#121212" : "#ffffff"

            let shareHTML = makeShareHTML(
                from: html,
                title: title,
                textColor: textColor,
                backgroundColor: backgroundColor
            )

            let width = max(webProvider.webView.bounds.width, UIScreen.main.bounds.width)

            var renderer: OffscreenHTMLSnapshotRenderer?

            renderer = OffscreenHTMLSnapshotRenderer(
                html: shareHTML,
                width: width
            ) { image in
                if let renderer {
                    activeRenderers.removeAll { $0 === renderer }
                }

                presentShareSheet(image: image)
            }

            if let renderer {
                activeRenderers.append(renderer)
                renderer.start()
            }
        }
    }

    private static func makeShareHTML(
        from html: String,
        title: String,
        textColor: String,
        backgroundColor: String
    ) -> String {
        let titleHTML = """
        <div style="
            text-align: center;
            font-size: 47px;
            font-weight: bold;
            padding: 14px 8px 12px 8px;
            color: \(textColor);
            background-color: \(backgroundColor);
        ">
            \(escapeHTML(title))
        </div>
        """

        guard
            let bodyRange = html.range(of: "<body", options: .caseInsensitive),
            let insertRange = html[bodyRange.lowerBound...].range(of: ">")
        else {
            return """
            <html>
            <body>
            \(titleHTML)
            \(html)
            </body>
            </html>
            """
        }

        var result = html
        result.insert(contentsOf: titleHTML, at: insertRange.upperBound)
        return result
    }

    private static func presentShareSheet(image: UIImage) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return
        }

        root.present(activityVC, animated: true)
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

@MainActor
private final class OffscreenHTMLSnapshotRenderer: NSObject, WKNavigationDelegate {

    private let html: String
    private let width: CGFloat
    private let completion: (UIImage) -> Void

    private var webView: WKWebView?

    init(
        html: String,
        width: CGFloat,
        completion: @escaping (UIImage) -> Void
    ) {
        self.html = html
        self.width = width
        self.completion = completion
    }

    func start() {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return
        }

        let webView = WKWebView(
            frame: CGRect(x: -10000, y: 0, width: width, height: 1)
        )

        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        root.view.addSubview(webView)

        self.webView = webView

        webView.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.capture()
        }
    }

    private func capture() {
        guard let webView else {
            return
        }

        let contentSize = CGSize(
            width: max(webView.scrollView.contentSize.width, width),
            height: max(webView.scrollView.contentSize.height, 1)
        )

        webView.frame = CGRect(
            x: -10000,
            y: 0,
            width: contentSize.width,
            height: contentSize.height
        )

        webView.scrollView.contentOffset = .zero
        webView.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: contentSize)

        let image = renderer.image { _ in
            webView.drawHierarchy(
                in: CGRect(origin: .zero, size: contentSize),
                afterScreenUpdates: true
            )
        }

        webView.navigationDelegate = nil
        webView.removeFromSuperview()

        completion(image)
    }
}
