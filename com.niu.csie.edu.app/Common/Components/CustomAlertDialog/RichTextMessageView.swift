import SwiftUI



struct RichTextMessageView: View {

    let parts: [AlertMessagePart]
    let linkActions: [String: () -> Void]
    let alignment: TextAlignment

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {

        let attributed = buildAttributedString()

        Text(attributed)
            .font(.system(size: isPad ? 23 : 15))
            .multilineTextAlignment(alignment)
            .environment(\.openURL, OpenURLAction { url in

                guard url.scheme == "myapp",
                      url.host == "alertlink",
                      let id = url.path.split(separator: "/").map(String.init).last
                else {
                    return .systemAction
                }

                linkActions[id]?()
                return .handled
            })
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()

        for part in parts {
            switch part {

            case .text(let s):
                result.append(AttributedString(s))

            case .textKey(let key):
                result.append(AttributedString(localized(key)))

            case .link(let text, let id):
                result.append(makeLink(text: text, id: id))

            case .linkKey(let key, let id):
                result.append(makeLink(text: localized(key), id: id))

            case .textColor(let s, let color):
                var a = AttributedString(s)
                a.foregroundColor = color
                result.append(a)

            case .textKeyColor(let key, let color):
                var a = AttributedString(localized(key))
                a.foregroundColor = color
                result.append(a)
            }
        }

        return result
    }

    private func localized(_ key: LocalizedStringKey) -> String {
        let mirror = Mirror(reflecting: key)
        if let raw = mirror.children.first(where: { $0.label == "key" })?.value as? String {
            return NSLocalizedString(raw, comment: "")
        }
        return ""
    }

    private func makeLink(text: String, id: String) -> AttributedString {
        var a = AttributedString(text)
        a.link = URL(string: "myapp://alertlink/\(id)")
        a.foregroundColor = .blue
        a.underlineStyle = .single
        return a
    }
}
