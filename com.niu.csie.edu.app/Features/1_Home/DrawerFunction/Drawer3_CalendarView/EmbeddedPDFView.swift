import SwiftUI
import PDFKit



struct EmbeddedPDFView: UIViewRepresentable {
    let pdfURLString: String
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.backgroundColor = .clear
        
        // 關閉縮圖列
        pdfView.displaysAsBook = false
        pdfView.displaysPageBreaks = false
        pdfView.subviews
            .compactMap { $0 as? PDFThumbnailView }
            .forEach { $0.removeFromSuperview() }
        
        // 嘗試從快取中載入 PDF
        if let cachesDirectoryUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
           let lastPathComponent = URL(string: pdfURLString)?.lastPathComponent {
            let url = cachesDirectoryUrl.appendingPathComponent(lastPathComponent)
            if FileManager.default.fileExists(atPath: url.path),
               let document = PDFDocument(url: url) {
                pdfView.document = document
            } else {
                print("⚠️ PDF 不存在：\(url.path)")
            }
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // 不需要更新邏輯
    }
}
