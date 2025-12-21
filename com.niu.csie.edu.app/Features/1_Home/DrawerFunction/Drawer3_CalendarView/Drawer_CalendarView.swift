import SwiftUI
import PDFViewer



struct Drawer_CalendarView: View, DownloadManagerDelegate {
    
    @State private var loadingPDF: Bool = false
    @State private var progressValue: Float = 0.0
    @State private var pdfReady: Bool = false
    @State private var pdfURL: String = ""
    
    @State private var availableSemesters: [String] = []  // 行事曆底下所有節點，如 ["114", "115"]
    @State private var activeSemester: String = ""        // 目前顯示哪一個 semester
    
    @ObservedObject var downloadManager = DownloadManager.shared()
    @ObservedObject var appSettings = AppSettings()
    
    
    var body: some View {
        VStack {
            if loadingPDF {
                VStack {
                    ProgressView(value: $progressValue, visible: $loadingPDF)
                    Text("正在下載 PDF...")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
            } else if pdfReady {
                // 使用自定義嵌入版
                EmbeddedPDFView(pdfURLString: pdfURL)
                    .id(pdfURL) // 關鍵：讓 pdfURL 改變時，整個 UIViewRepresentable 重新建立
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 預設載入時的 placeholder（還沒準備好）
                Text("正在準備 PDF...")
                    .foregroundColor(.gray)
            }
        }
        .toolbar {                 // 插入右上角按鈕
            ToolbarItem(placement: .topBarTrailing) {
                if availableSemesters.count > 1,
                   let alt = alternativeSemester {
                    Button(action: {
                        switchSemester(to: alt)
                    }) {
                        Text(alt)  // 顯示另一個學期代號
                            .foregroundColor(.white)
                            .padding(.horizontal, 11)
                    }
                }
            }
        }
        .onAppear {
            fetchSemesterList()
        }
    }
    
    
    // MARK: - 抓所有行事曆節點
    private func fetchSemesterList() {
        FirebaseDatabaseManager.shared.readData(from: "行事曆") { value in
            if let dict = value as? [String: Any] {
                
                // dict.keys 會是 ["114", "115"]
                let keys = dict.keys.sorted()
                self.availableSemesters = keys
                
                let current = String(appSettings.semester)
                self.activeSemester = current
                
                if let url = dict[current] as? String {
                    loadPDF(urlString: url)
                }
            }
        }
    }
    
    
    // MARK: - 切換到另一個學期
    private var alternativeSemester: String? {
        if availableSemesters.count == 2 {
            return availableSemesters.first { $0 != activeSemester }
        }
        return nil
    }
    
    private func switchSemester(to new: String) {
        activeSemester = new
        
        FirebaseDatabaseManager.shared.readData(from: "行事曆/\(new)") { value in
            if let url = value as? String {
                loadPDF(urlString: url)
            }
        }
    }
    
    
    // MARK: - PDF Loading
    private func loadPDF(urlString: String) {
        self.pdfURL = urlString
        
        if fileExistsInDirectory(urlString: urlString) {
            self.pdfReady = true
        } else {
            self.pdfReady = false
            downloadPDF(pdfUrlString: urlString)
        }
    }
    
    
    // MARK: - File Handling
    private func fileExistsInDirectory(urlString: String) -> Bool {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileName = URL(string: urlString)?.lastPathComponent ?? "calendar.pdf"
        return fileManager.fileExists(atPath: cachesDirectory.appendingPathComponent(fileName).path)
    }
    
    private func downloadPDF(pdfUrlString: String) {
        guard let url = URL(string: pdfUrlString) else { return }
        downloadManager.delegate = self
        downloadManager.downloadFile(url: url)
    }
    
    
    // MARK: - DownloadManagerDelegate
    func downloadDidFinished(success: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadingPDF = false
            self.pdfReady = true
        }
    }
    
    func downloadDidFailed(failure: Bool) {
        DispatchQueue.main.async {
            self.loadingPDF = false
            print("PDFCatalogueView: Download failure")
        }
    }
    
    func downloadInProgress(progress: Float, totalBytesWritten: Float, totalBytesExpectedToWrite: Float) {
        DispatchQueue.main.async {
            self.loadingPDF = true
            self.progressValue = progress
        }
    }
}
