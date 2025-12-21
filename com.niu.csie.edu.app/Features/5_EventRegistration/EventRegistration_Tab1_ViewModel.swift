import SwiftUI
import Combine



@MainActor
final class EventRegistration_Tab1_ViewModel: ObservableObject {
    
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    
    @Published var events: [EventData] = []
    
    @Published var showEventDetailDialog: Bool = false
    @Published var isPostHandled: Bool = false // 新增標誌位
    // 新增 toast 控制
    @Published var showToast: Bool = false
    // 選中的 EventData 資訊
    @Published var selectedEventForDetail: EventData?
    private var selectedEventID: String? // 儲存點擊的ID，否則無法傳到 setupCallbacks
    
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    // --- 全域注射 ---
    private let sso = SSOIDSettings.shared
    // --- JS ---
    private let jsGetData: String = """
        (function() { 
            var data = []; 
            var skip = 0; 
            var count = document.querySelector('.col-md-11.col-md-offset-1.col-sm-10.col-xs-12.col-xs-offset-0').querySelectorAll('.row.enr-list-sec').length;
            for(let i=0; i<count; i++) {
                let row = document.querySelectorAll('.row.enr-list-sec')[i]; // 報名項目 父容器
                let dialog = row.querySelector('.table'); // 活動詳情 Dialog 父容器
                let name = row.querySelector('h3').innerText.trim(); // 名稱
                let department = row.querySelector('.col-sm-3.text-center.enr-list-dep-nam.hidden-xs').title.split('：')[1].trim(); // 主辦單位
                let state = row.querySelector('.badge.alert-danger').innerText.trim(); // 報名狀態
                if (state === '活動已結束') {count--;skip++;continue;} // 活動結束 直接跳過
                let targets = row.querySelector('.fa-id-badge').parentElement.innerText.trim(); // 活動對象
                if (!targets.includes('本校在校生')) {count--;skip++;continue;} // 活動對象不包含學生 直接跳過
                let eventSerialID = row.querySelector('p').innerText.split('：')[1].split(' ')[0].trim(); // 活動編號
                let eventTime = row.querySelector('.fa-calendar').parentElement.innerText.replace(/\\s+/g,'').replace('~','起\\n')+'止'.trim(); // 活動時間
                let eventLocation = row.querySelector('.fa-map-marker').parentElement.innerText.trim(); // 活動地點
                let eventRegisterTime = row.querySelector('.table').querySelectorAll('tr')[9].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').replace('~','起\\n')+'止'.trim(); // 報名時間
                let eventDetail = dialog.querySelectorAll('tr')[3].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').replace('<br>','\\n').replace('\"','').trim(); // 活動說明
                let contactInfoText = dialog.querySelectorAll('tr')[5].querySelectorAll('td')[1].innerHTML; // 聯絡資訊(3項)
                let contactInfos = contactInfoText.split('<br>').map(function(info) {
                    return info.replace(/<[^>]*>/g,'').trim();
                }); // 以 [index] 抓取3項資訊
                let Related_links = dialog.querySelectorAll('tr')[6].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').trim(); // 相關連結
                let Remark = dialog.querySelectorAll('tr')[7].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').replace('<br>','\\n').replace('\"','').trim(); // 備註
                let Multi_factor_authentication = dialog.querySelectorAll('tr')[8].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').replace('<br>','\\n').replace('已認證，','').replace('\"','').trim(); // 多元認證
                let eventPeople = row.querySelector('.fa-user-plus').parentElement.innerText.replace(/\\s+/g,'').replace('，','人\\n')+'人'.trim(); // 報名人數
                // console.log(eventRegisterTime);
                // let eventDescription = row.querySelector('.small.hidden-xs').innerText.trim();
                data[i-skip] = {name, department, state, eventSerialID, eventTime, eventLocation, eventRegisterTime, eventDetail, contactInfoName: contactInfos[0], contactInfoTel: contactInfos[1], contactInfoMail: contactInfos[2], Related_links, Remark, Multi_factor_authentication, eventPeople};
            }
            return JSON.stringify(data);
        })();
        """
    
    
    init() {
        let ccsysURL = sso.ccsys
        // 初始化 WebView
        self.webProvider = WebView_Provider(
            initialURL: "https://ccsys.niu.edu.tw/SSO/" + ccsysURL,
            userAgent: .desktop
        )
        // 註冊廣播監聽訊息，取消報名後重新載入網址，會觸發 refresh
        NotificationCenter.default.addObserver(
            forName: .didChangeEventRegistration,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.webProvider.load(url: "https://ccsys.niu.edu.tw/MvcTeam/Act")
            }
        }
        setupCallbacks()
    }
    
    // 重新加載列表，無論是剛開始或是送出報名
    private func refresh() {
        webProvider.evaluateJS(jsGetData) { [weak self] result in
            guard let self = self else { return }
            if let jsonString = result {
                do {
                    // 將字串轉成 Data
                    let jsonData = jsonString.data(using: .utf8)!

                    // 嘗試解析成陣列（對應 JSONArray）
                    if let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                        let decodedEvents = jsonArray.compactMap { dict -> EventData? in
                            
                            guard
                                let name = dict["name"] as? String,
                                let department = dict["department"] as? String,
                                let event_state = dict["state"] as? String,
                                let eventSerialID = dict["eventSerialID"] as? String,
                                let eventTime = dict["eventTime"] as? String,
                                let eventLocation = dict["eventLocation"] as? String,
                                let eventRegisterTime = dict["eventRegisterTime"] as? String,
                                let eventDetail = dict["eventDetail"] as? String,
                                let contactInfoName = dict["contactInfoName"] as? String,
                                let contactInfoTel = dict["contactInfoTel"] as? String,
                                let contactInfoMail = dict["contactInfoMail"] as? String,
                                let Related_links = dict["Related_links"] as? String,
                                let Remark = dict["Remark"] as? String,
                                let Multi_factor_authentication = dict["Multi_factor_authentication"] as? String,
                                let eventPeople = dict["eventPeople"] as? String
                                
                            else { return nil }

                            return EventData(
                                name: name,
                                department: department,
                                event_state: event_state,
                                eventSerialID: eventSerialID,
                                eventTime: eventTime,
                                eventLocation: eventLocation,
                                eventRegisterTime: eventRegisterTime,
                                eventDetail: eventDetail,
                                contactInfoName: contactInfoName,
                                contactInfoTel: contactInfoTel,
                                contactInfoMail: contactInfoMail,
                                Related_links: Related_links,
                                Multi_factor_authentication: Multi_factor_authentication,
                                eventPeople: eventPeople,
                                Remark: Remark
                            )
                        }

                        // 更新畫面
                        DispatchQueue.main.async {
                            self.events = decodedEvents
                        }
                    }


                } catch {
                    print("❌ JSON parse error: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ evaluateJS 無法轉換為字串結果")
            }
            self.showPage()
        }
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
                if progress < 1.0 {
                    self.isOverlayVisible = true
                }
            }
        }
    }
    
    private func handlePageFinished(url: String?) {
        switch url {
        case "https://ccsys.niu.edu.tw/MvcTeam/Act":
            refresh()
            // isOverlayVisible = false
        default: // 進入選擇的活動，準備報名
            if (isPostHandled) {
                webProvider.evaluateJS("document.querySelector('[name=\"__RequestVerificationToken\"]').value") { [weak self] token in
                    guard let self = self else { return }
                    handleRegisterEvent(token: token!, EventID: selectedEventID!, PostURL: url!)
                }
            }
            break
        }
    }
    
    func RegisterEvent(EventID: String) {
        isOverlayVisible = true
        selectedEventID = EventID
        webProvider.load(url: "https://ccsys.niu.edu.tw/MvcTeam/Act/Apply/"+EventID)
    }
    
    private func handleRegisterEvent(token: String, EventID: String, PostURL: String) {
        // 組合 post 資訊
        let orderedParams: [(String, String)] = [
            ("__RequestVerificationToken", token),
            ("id", EventID),
            ("action", "我要報名")
        ]
        webProvider.loadPost(url: PostURL, orderedBody: orderedParams)
        checkRegistrationStatus()
    }
    
    private func checkRegistrationStatus() {
        isPostHandled = false // Post 完成，先把標誌位改回 false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.webProvider.evaluateJS("""
                (function() {
                    var h1Element = document.querySelector('h1.text-danger.text-shadow');
                    return h1Element ? h1Element.innerText.includes('已報名') : false;
                })();
            """) {  [weak self] result in
                // 這裡一定要用 ! ，否則會有 Optional
                // 和 Android 不同，這裡true是"1" false是"0"
                guard let self = self else { return }

                if result! == "1" {
                    showToast = true
                    // 報名成功後發送通知，通知 Tab2 Refresh
                    NotificationCenter.default.post(name: .didSubmitEventRegistration, object: nil)
                    webProvider.load(url: "https://ccsys.niu.edu.tw/MvcTeam/Act")
                } else {
                    checkRegistrationStatus()
                }
            }
        }
    }
    
    
    // --- 顯示畫面（模仿 Android 的 hideProgressOverlay + setVisibility） ---
    private func showPage() {
        isOverlayVisible = false
        // print("顯示頁面完成")
    }
}
