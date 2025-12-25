import SwiftUI
import Combine
import MapKit



@MainActor
final class ZuvioViewModel: ObservableObject {
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    @Published var isWebVisible = false
    // --- Map相關 ---
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    // 新增 toast 控制 (偽定位)
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    
    // --- JS：隱藏多餘元素 ---
    let jsHideElements = """
    ['forum', 'zook', 'direno', 'match', 'setting'].forEach(function(type) {
        document.querySelectorAll('.g-f-button-box[data-type="' + type + '"]').forEach(function(el) {
            el.style.display = 'none';
        });
    });
    document.querySelector('.i-m-p-wisdomhall-area').style.display = 'none';
    document.querySelectorAll('.i-m-p-c-a-c-l-course-box[data-course-id="399868"]').forEach(function(el) {
        el.style.display = 'none';
    });
    """
    
    // --- JS：暗黑模式樣式 ---
    let jsDarkMode = """
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'html {filter: invert(0.90) !important}';
    document.lastElementChild.appendChild(document.createElement('style')).textContent = 'video, img, div.image, div.s-i-t-b-wrapper, div.i-c-l-reload-button, div.g-f-button-box, div.i-a-c-q-t-q-b-top-box, div.button, div.i-r-reload-button, div.i-f-f-f-a-post-feedback-button, div.i-m-p-c-a-c-l-c-b-green-block, div.i-m-p-c-a-c-l-c-b-t-star, div.s-i-top-box, div.s-i-t-b-i-b-icon, div.p-m-c-icon-box, div.user-icon-switch, div.c-pm-c-chat-wrapper.message-box, div.c-pm-c-send-message, div.c-pm-c-receive-message, div.c-pm-c-r-text, div.c-pm-c-s-text, div.c-pm-c-r-icon, div.c-pm-c-r-redirect, div.c-pm-c-chat-topic-card-list, div.i-h-r-rollcall-row.i-h-r-r-r-nonarrival, div.i-h-r-rollcall-row.i-h-r-r-r-punctual {filter: invert(100%) !important;}';
    """
    
    // --- JS：偽定位 ---
    let jsFakeGPS = """
    javascript:(function() {
        function enableSubmitButton(){
            $("#submit-make-rollcall").removeClass('i-r-f-b-disabled-button');
            $("#submit-make-rollcall").addClass('i-r-f-b-make-rollcall-button');
            $("#submit-make-rollcall").attr('onclick','makeRollcall(rollcall_id)');
            $('.open-gps-guidance-link').addClass('hidden');
            $('.open-gps-guidance-link-text-close').addClass('hidden');
            $('.open-gps-guidance-link-text-open').removeClass('hidden');
        }

        window.irs_getLocation = function(callback) {
            user_gps = true;
            user_latitude = ___latitude___;
            user_longitude = ___longitude___;
            callback();
        };

        window.makeRollcall = function(rollcall_id) {
            $("button#submit-make-rollcall").disableBtn();
            google_ga_event('irs', 'IRS-學生簽到');

            $.ajax({
                url: site_url + 'app_v2/makeRollcall',
                type: 'POST',
                data: {
                    user_id: user_id,
                    accessToken: accessToken,
                    rollcall_id: rollcall_id,
                    device: 'WEB',
                    lat: user_latitude,
                    lng: user_longitude
                },
                dataType: 'json'
            }).success(function (data) {
                if (data.status) {
                    rollcallFinishFcbx(data.ad.answer);
                } else {
                    switch (data.msg) {
                        case 'ROLLCALL IS ANSWERED':
                            student5Fancybox('#rollcall-refinish-fcbx-btn', 305);
                            break;
                        case 'LOSE THE GPS LOCATION':
                            student5Fancybox('#rollcall-fail-fcbx-btn', 305);
                            break;
                        case 'ROLLCALL IS NOT ONAIR':
                            student5Fancybox('#rollcall-unopen-fcbx-btn', 305);
                            break;
                        default:
                            student5Fancybox('#rollcall-fail-fcbx-btn', 305);
                            break;
                    }
                }
            });
        };

        irs_getLocation(enableSubmitButton);
    })();
    """
    
    // --- 紀錄系統是否為深色模式 ---
    var colorScheme: ColorScheme = .light
    
    
    init() {
        self.webProvider = WebView_Provider(
            initialURL: "https://irs.zuvio.com.tw/student5/irs/index",
            userAgent: .mobile
        )
        setupCallbacks()
    }
    
    // 選擇位置會觸發，無論什麼頁面
    // 選擇位置完成，強制重載，觸發 handlePageFinished 底下的注射
    // 避免 SPA 導致網址跑到首頁
    func updateCoordinate( _ coordinate: CLLocationCoordinate2D?, toastMessage: String? = nil) {
        selectedCoordinate = coordinate
        webProvider.reload()
        // Toast
        if let toastMessage {
            self.toastMessage = toastMessage
        } else if let coordinate {
            // 有座標 → 預設顯示經緯度（地圖選點）
            self.toastMessage = String.localized(
                "Toast_Choosed_Map_Location",
                String(format: "%.6f", coordinate.latitude),
                String(format: "%.6f", coordinate.longitude)
            )
        } else {
            // 無座標 → 預設行為（取消 / 清除定位）
            self.toastMessage = String.localized(
                "Toast_Choosed_Location_MenuItem",
                NSLocalizedString("Cancel_Mock", comment: "")
            )
        }
        showToast = true
    }
    
    // --- 綁定 WebView 回呼事件 ---
    private func setupCallbacks() {
        webProvider.onPageFinished = { [weak self] url in
            guard let self = self else { return }
            Task { @MainActor in
                self.handlePageFinished(url: url)
            }
        }
        
        webProvider.onProgressChanged = { [weak self] progress in
            guard let self = self else { return }
            Task { @MainActor in
                // self.overlayText = LocalizedStringKey("loading")
                // self.webProvider.setVisible(false)
                if progress < 1.0 {
                    self.isWebVisible = false
                    self.isOverlayVisible = true
                }
            }
        }
    }
    
    // --- 初始化狀態 ---
    func initializeState() {
        webProvider.setVisible(false)
    }
    
    // --- 頁面載入完成時的處理邏輯 ---
    private func handlePageFinished(url: String?) {
        // print("頁面載入完成: \(url ?? "未知網址")")
        webProvider.evaluateJS(jsHideElements) { [weak self] _ in
            guard let self = self else { return }
            // 2. 若有選擇位置，注入 JS FakeGPS
            if let coordinate = selectedCoordinate {
                let js_fake = jsFakeGPS
                    .replacingOccurrences(of: "___latitude___",
                                               with: String(coordinate.latitude))
                    .replacingOccurrences(of: "___longitude___",
                                               with: String(coordinate.longitude))
                webProvider.evaluateJS(js_fake)
            }
            // 2. 如果是 Dark Mode，執行反白樣式
            if self.colorScheme == .dark {
                // print("啟用暗黑模式 JS")
                self.webProvider.evaluateJS(self.jsDarkMode) { _ in
                    self.showPage()
                }
            } else {
                self.showPage()
            }
        }
    }
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isWebVisible = true
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}


extension String {
    static func localized(
        _ key: String,
        _ args: CVarArg...
    ) -> String {
        String(
            format: NSLocalizedString(key, comment: ""),
            arguments: args
        )
    }
}
