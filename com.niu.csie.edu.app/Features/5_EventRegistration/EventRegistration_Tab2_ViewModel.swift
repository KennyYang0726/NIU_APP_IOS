import SwiftUI
import Combine



@MainActor
final class EventRegistration_Tab2_ViewModel: ObservableObject {
    
    // --- 狀態 ---
    @Published var isOverlayVisible = true
    @Published var overlayText: LocalizedStringKey = "loading"
    
    @Published var events: [EventData_Apply] = []
    
    @Published var showEventDetailDialog: Bool = false
    @Published var isPostHandled: Bool = false // 新增標誌位
    @Published var showModdingEventInfoDialog: Bool = false
    
    // 新增 toast 控制
    @Published var showToast: Bool = false
    @Published var toastMessage: LocalizedStringKey = ""
    // 選中的 EventData 資訊
    @Published var selectedEventForDetail: EventData_Apply?
    // 傳入 修改資料頁面 資訊 (dict)
    @Published var selectedEventForModdingInfo: EventInfo?
    var selectedEventID: String? // 儲存點擊的ID，否則無法傳到 setupCallbacks
    
    // --- WebView 相關 ---
    let webProvider: WebView_Provider
    // --- 全域注射 ---
    private let sso = SSOIDSettings.shared
    // --- JS ---
    private let jsGetData: String = """
        (function() { 
            var data = []; 
            var count = document.querySelector('.col-md-11.col-md-offset-1.col-sm-10.col-xs-12.col-xs-offset-0').querySelectorAll('.row.enr-list-sec').length;
            for(let i=0; i<count; i++) {
                let row = document.querySelectorAll('.row.enr-list-sec')[i]; // 報名項目 父容器
                let row_state = document.querySelectorAll('.row.bg-warning')[i]; // 報名狀態 父容器
                let dialog = row.querySelector('.table'); // 活動詳情 Dialog 父容器
                let name = row.querySelector('h3').innerText.trim(); // 名稱
                let department = row.querySelector('.col-sm-3.text-center.enr-list-dep-nam.hidden-xs').title.split('：')[1].trim(); // 主辦單位
                let state = row_state.querySelector('.text-danger.text-shadow').innerText.split('：')[1].trim(); // 報名狀態 (正取/候補/現場)
                let event_state = row.querySelector('.btn.btn-danger').innerText.trim(); // 活動狀態
                let eventSerialID = row.querySelector('p').innerText.split('：')[1].split(' ')[0].trim(); // 活動編號
                let eventTime = row.querySelector('.fa-calendar').parentElement.innerText.replace(/\\s+/g,'').replace('~','起\\n')+'止'.trim(); // 活動時間
                let eventLocation = row.querySelector('.fa-map-marker').parentElement.innerText.trim(); // 活動地點
                let eventDetail = dialog.querySelectorAll('tr')[3].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').replace('<br>','\\n').replace('\"','').trim(); // 活動說明
                let contactInfoText = dialog.querySelectorAll('tr')[5].querySelectorAll('td')[1].innerHTML; // 聯絡資訊(3項)
                let contactInfos = contactInfoText.split('<br>').map(function(info) {
                    return info.replace(/<[^>]*>/g,'').trim();
                }); // 以 [index] 抓取3項資訊
                let Related_links = dialog.querySelectorAll('tr')[6].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').trim(); // 相關連結
                let Remark = dialog.querySelectorAll('tr')[7].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').replace('<br>','\\n').replace('\"','').trim(); // 備註
                let Multi_factor_authentication = dialog.querySelectorAll('tr')[8].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').replace('<br>','\\n').replace('\"','').trim(); // 多元認證
                let eventRegisterTime = dialog.querySelectorAll('tr')[9].querySelectorAll('td')[1].textContent.replace(/\\s+/g,'').replace('~','~\\n').trim(); // 報名時間
                // let eventPeople = row.querySelector('.fa-user-plus').parentElement.innerText.replace(/\\s+/g,'').replace('，','人\\n')+'人'.trim(); // 報名人數
                data[i] = {name, department, state, event_state, eventSerialID, eventTime, eventLocation, eventDetail, contactInfoName: contactInfos[0], contactInfoTel: contactInfos[1], contactInfoMail: contactInfos[2], Related_links, Remark, Multi_factor_authentication, eventRegisterTime};
            }
            return JSON.stringify(data);
        })();
        """
    
    private let getInfo = """
    (function() {
        let RequestVerificationToken = document.querySelector('[name="__RequestVerificationToken"]').value;
        let SignId = document.getElementById('SignId').value;
        let role = document.querySelectorAll('.col-xs-8')[0].innerText.trim();
        let classes = document.querySelectorAll('.col-xs-8')[1].innerText.trim();
        let schnum = document.querySelectorAll('.col-xs-8')[2].innerText.trim();
        let name = document.querySelectorAll('.col-xs-8')[3].innerText.trim();
        let Tel = document.getElementById('SignTEL').value.toString();
        let Mail = document.getElementById('SignEmail').value;
        let Remark = document.getElementById('SignMemo').value;
        let selectedFood = document.querySelector('input[name="Food"]:checked').value;
        var selectedProof = document.querySelector('input[name="Proof"]:checked').value;
        // 處理選擇第三項 公務人員時數
        if (selectedProof == "3") {
            selectedProof = "2"; // 需要證明
        }
        let result = {
            'RequestVerificationToken': RequestVerificationToken,
            'SignId': SignId,
            'role': role,
            'classes': classes,
            'schnum': schnum,
            'name': name,
            'Tel': String(Tel),
            'Mail': Mail,
            'selectedFood': selectedFood,
            'selectedProof': selectedProof,
            'Remark': Remark
        };
        return JSON.stringify(result);
    })();
    """

    
    init() {
        let ccsysURL = sso.ccsys
        // 初始化 WebView
        self.webProvider = WebView_Provider(
            initialURL: "https://ccsys.niu.edu.tw/SSO/" + ccsysURL,
            userAgent: .desktop
        )
        // 註冊廣播監聽訊息，報名後重新載入網址，會觸發 refresh
        NotificationCenter.default.addObserver(
            forName: .didSubmitEventRegistration,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.webProvider.load(url: "https://ccsys.niu.edu.tw/MvcTeam/Act/ApplyMe")
            }
        }
        setupCallbacks()
    }
    
    // 重新加載列表，無論是剛開始或是取消報名
    private func refresh() {
        webProvider.evaluateJS(jsGetData) { [weak self] result in
            guard let self = self else { return }
            if let jsonString = result {
                do {
                    // 將字串轉成 Data
                    let jsonData = jsonString.data(using: .utf8)!
                    
                    // 嘗試解析成陣列（對應 JSONArray）
                    if let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                        let decodedEvents = jsonArray.compactMap { dict -> EventData_Apply? in
                            
                            guard
                                let name = dict["name"] as? String,
                                let department = dict["department"] as? String,
                                let state = dict["state"] as? String, // 正/備取
                                let event_state = dict["event_state"] as? String, // 活動已結束, 報名截止...
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
                                let Multi_factor_authentication = dict["Multi_factor_authentication"] as? String
                                
                            else { return nil }

                            return EventData_Apply(
                                name: name,
                                department: department,
                                state: state,
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
                                Remark: Remark
                            )
                        }
                        // 更新畫面
                        DispatchQueue.main.async {
                            self.events = decodedEvents
                        }
                    }

                } catch {
                    print("JSON parse error: \(error.localizedDescription)")
                }
            } else {
                print("evaluateJS 無法轉換為字串結果")
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
            webProvider.load(url: "https://ccsys.niu.edu.tw/MvcTeam/Act/ApplyMe")
        case "https://ccsys.niu.edu.tw/MvcTeam/Act/ApplyMe":
            refresh()
            // isOverlayVisible = false
        default: // 修改報名資訊/取消報名
            if (!isPostHandled) { // isPostHandled -> true 是在 EventRegistrationTabView 點擊按鈕後改變
                // 點開編輯報名資訊頁面
                // 先來抓取資料
                webProvider.evaluateJS(getInfo) { [weak self] info in
                    guard let self = self else { return }
                    // 解析 JS 回傳的 JSON 字串
                    if let jsonString = info,
                       let data = jsonString.data(using: .utf8) {
                        do {
                            let decoded = try JSONDecoder().decode(EventInfo.self, from: data)
                            // 顯示 Dialog 部分交給 EventRegistrationTabView
                            // 這邊只管 帶入頁面資料，改編標誌，把 prog 隱藏掉
                            DispatchQueue.main.async {
                                self.selectedEventForModdingInfo = decoded
                                self.showModdingEventInfoDialog = true
                            }
                        } catch {
                            print("JSON 解析錯誤：\(error)")
                        }
                    } else {
                        print("evaluateJS 沒有回傳預期的字串")
                    }
                }
            }
            break
        }
    }
    
    func ModdingEventInfo(EventID: String) {
        isOverlayVisible = true
        selectedEventID = EventID
        webProvider.load(url: "https://ccsys.niu.edu.tw/MvcTeam/Act/RegData/"+EventID)
    }
    
    // 處理 修改／取消 報名
    func HandlePost(EventID: String, requestVerificationToken: String, signID: String, tel: String, mail: String, remark: String, food: String, proof: String, actions: String) {
        
        let postURL = "https://ccsys.niu.edu.tw/MvcTeam/Act/RegData/\(EventID)"
        // 組合 post 資訊
        let orderedParams: [(String, String)] = [
            ("__RequestVerificationToken", requestVerificationToken),
            ("ApplyId", EventID),
            ("SignId", signID),
            ("SignTEL", tel),
            ("SignEmail", mail),
            ("SignMemo", remark),
            ("Food", food),
            ("Proof", proof),
            ("action", actions)
        ]
        // 改變 toast 內容
        if actions == "確定取消" {
            toastMessage = "Event_ModInfo_btn1_success"
        } else if actions == "儲存修改" {
            toastMessage = "Event_ModInfo_btn2_success"
        }
        // === 重點：使用 JavaScript 直接在 DOM 內組 form 並 submit ===
        // 由於 apple 有個鳥毛內建安全限制規定，
        // 當它發現：表單目標（action URL）＝ 當前頁面（self-POST）
        // policyListener->ignore(WasNavigationIntercepted);
        // 『 這種 self-POST 很容易被惡意網頁用來強制重新送出相同請求（例如 spam form）』
        // 所以無法使用 .loadPost 方法
        let jsFormSubmit = """
        (function() {
            try {
                var form = document.createElement('form');
                form.method = 'POST';
                form.action = '\(postURL)';
                form.target = '_self';
                    
                function addInput(name, value) {
                    var input = document.createElement('input');
                    input.type = 'hidden';
                    input.name = name;
                    input.value = value;
                    form.appendChild(input);
                }
                    
                \(orderedParams.map { "addInput('\($0.0)', '\($0.1)');" }.joined(separator: "\n"))
                
                document.body.appendChild(form);
                form.submit();
                return "submitted";
            } catch(e) {
                return "error: " + e.message;
            }
        })();
        """
        // 執行表單提交（由 JS 端送出，不會被 WebKit 攔截）
        webProvider.evaluateJS(jsFormSubmit) { [weak self] result in
            guard let self = self else { return }
            print("JS form submit result:", result ?? "nil")
            checkPostStatus()
        }
    }
    
    private func checkPostStatus() {
        isPostHandled = false // Post 完成，先把標誌位改回 false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.webProvider.evaluateJS("""
                (function() {
                    var h1Element = document.querySelector('h1.text-danger.text-shadow');
                    return h1Element ? h1Element.innerText.includes('報名') : false;
                })();
            """) {  [weak self] result in
                // 這裡一定要用 ! ，否則會有 Optional
                // 和 Android 不同，這裡true是"1" false是"0"
                guard let self = self else { return }

                if result! == "1" {
                    showToast = true
                    // 報名狀態改變(取消／修改)後發送通知，通知 Tab1 Refresh
                    NotificationCenter.default.post(name: .didChangeEventRegistration, object: nil)
                    webProvider.load(url: "https://ccsys.niu.edu.tw/MvcTeam/Act/ApplyMe")
                } else {
                    checkPostStatus()
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
