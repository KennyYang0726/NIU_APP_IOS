import SwiftUI



struct QRCodeScanView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var isScanningAnimated = false
    @StateObject private var vm = QRCodeScanViewModel()
    
    let onValidURLScanned: (String) -> Void
    
    var body: some View {
        ZStack {
            QRScannerView { code in
                vm.handleScannedCode(code) { validURL in
                    onValidURLScanned(validURL)
                    dismiss()
                }
            }
            .ignoresSafeArea()
            
            scannerOverlay
            
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                Text(LocalizedStringKey("Event_qrcode_scan_text"))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(10)
                    .padding(.bottom, 40)
            }
        }
        .toast(isPresented: $vm.showToast) {
            Text(LocalizedStringKey("Event_qrcode_scan_Invalid"))
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
        }
    }
    
    private var scannerOverlay: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let size: CGFloat = min(width * 0.72, 280)
            let cornerRadius: CGFloat = 20
            let cornerLength: CGFloat = 28
            let lineWidth: CGFloat = 4

            let scanRect = CGRect(
                x: (width - size) / 2,
                y: (height - size) / 2,
                width: size,
                height: size
            )

            ZStack {
                Path { path in
                    path.addRect(CGRect(x: 0, y: 0, width: width, height: height))
                    path.addPath(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .path(in: scanRect)
                    )
                }
                .fill(
                    Color.black.opacity(0.35),
                    style: FillStyle(eoFill: true)
                )

                cornerGuides(
                    in: scanRect,
                    cornerRadius: cornerRadius,
                    cornerLength: cornerLength,
                    lineWidth: lineWidth
                )
                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                scanningLine(in: scanRect)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private func cornerGuides(
        in rect: CGRect,
        cornerRadius: CGFloat,
        cornerLength: CGFloat,
        lineWidth: CGFloat
    ) -> Path {
        var path = Path()

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        // 左上
        path.move(to: CGPoint(x: minX, y: minY + cornerLength))
        path.addLine(to: CGPoint(x: minX, y: minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: minX + cornerRadius, y: minY),
            control: CGPoint(x: minX, y: minY)
        )
        path.addLine(to: CGPoint(x: minX + cornerLength, y: minY))

        // 右上
        path.move(to: CGPoint(x: maxX - cornerLength, y: minY))
        path.addLine(to: CGPoint(x: maxX - cornerRadius, y: minY))
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: minY + cornerRadius),
            control: CGPoint(x: maxX, y: minY)
        )
        path.addLine(to: CGPoint(x: maxX, y: minY + cornerLength))

        // 左下
        path.move(to: CGPoint(x: minX, y: maxY - cornerLength))
        path.addLine(to: CGPoint(x: minX, y: maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: minX + cornerRadius, y: maxY),
            control: CGPoint(x: minX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX + cornerLength, y: maxY))

        // 右下
        path.move(to: CGPoint(x: maxX - cornerLength, y: maxY))
        path.addLine(to: CGPoint(x: maxX - cornerRadius, y: maxY))
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: maxY - cornerRadius),
            control: CGPoint(x: maxX, y: maxY)
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY - cornerLength))

        return path
    }
    
    @ViewBuilder
    private func scanningLine(in rect: CGRect) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.9),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: rect.width * 0.82, height: 3)
            .position(
                x: rect.midX,
                y: isScanningAnimated
                    ? rect.maxY - 16
                    : rect.minY + 16
            )
            .animation(
                .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: isScanningAnimated
            )
            .onAppear {
                isScanningAnimated = true
                DispatchQueue.main.async {
                    isScanningAnimated = true
                }
            }
    }
    
}
