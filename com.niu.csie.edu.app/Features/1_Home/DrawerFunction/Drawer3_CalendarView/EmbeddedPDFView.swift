import SwiftUI
import PDFKit

struct EmbeddedPDFView: UIViewRepresentable {
    let pdfURLString: String
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .clear
        
        // 重點：連續捲動時不要開 usePageViewController
        // pdfView.usePageViewController(true, withViewOptions: nil)

        loadPDF(into: pdfView)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        loadPDF(into: uiView)
    }
    
    private func loadPDF(into pdfView: PDFView) {
        guard let cachesDirectoryUrl = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first,
        let lastPathComponent = URL(string: pdfURLString)?.lastPathComponent else {
            return
        }
        
        let url = cachesDirectoryUrl.appendingPathComponent(lastPathComponent)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("PDF不存在：\(url.path)")
            return
        }
        
        guard let document = PDFDocument(url: url) else {
            print("PDFDocument建立失敗：\(url.path)")
            return
        }
                
        if pdfView.document !== document {
            pdfView.document = document
            pdfView.autoScales = true
        }
    }
}
