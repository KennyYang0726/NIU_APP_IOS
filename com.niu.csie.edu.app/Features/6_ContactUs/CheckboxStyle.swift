import SwiftUI



struct CheckboxStyle: ToggleStyle {
    var size: CGFloat = 24  // 可傳入大小

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: size, height: size)
                .foregroundColor(Color("ColorPrimary"))
                .onTapGesture { configuration.isOn.toggle() }
            configuration.label
        }
    }
}

