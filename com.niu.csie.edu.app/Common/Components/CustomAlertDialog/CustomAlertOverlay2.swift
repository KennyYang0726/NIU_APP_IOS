import SwiftUI


// 雙按鈕
struct CustomAlertOverlay2: View {

    let title: LocalizedStringKey
    let icon: Image?
    let message: AlertMessage
    let messageAlignment: TextAlignment
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let linkActions: [String: () -> Void]?

    init(
        title: LocalizedStringKey,
        icon: Image? = nil,
        message: AlertMessage,
        messageAlignment: TextAlignment = .center,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        linkActions: [String: () -> Void]? = nil
    ) {
        self.title = title
        self.icon = icon
        self.message = message
        self.messageAlignment = messageAlignment
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.linkActions = linkActions
    }

    var body: some View {
        CustomAlertBase(
            title: title,
            icon: icon,
            message: message,
            linkActions: linkActions,
            buttons: [
                AlertButtonConfig(titleKey: "Dialog_Cancel", action: onCancel),
                AlertButtonConfig(titleKey: "Dialog_OK", action: onConfirm)
            ],
            messageAlignment: messageAlignment
        )
    }
}
