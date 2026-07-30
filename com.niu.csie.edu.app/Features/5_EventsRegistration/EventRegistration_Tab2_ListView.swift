import SwiftUI


// MARK: - Tab2 專用的顯示詳情
struct EventData_Apply: Identifiable, Codable {
    var id: String { eventSerialID } // 給 ForEach 用
    let name: String
    let department: String
    let state: String
    let event_state: String
    let eventSerialID: String
    let eventTime: String
    let eventLocation: String
    let eventRegisterTime: String
    let eventDetail: String
    let contactInfoName: String
    let contactInfoTel: String
    let contactInfoMail: String
    let Related_links: String
    let Multi_factor_authentication: String
    let Remark: String
}

// MARK: - Tab2 專用的修改報名資料
struct EventInfo: Codable {
    var RequestVerificationToken: String
    var SignId: String
    var role: String
    var classes: String
    var schnum: String
    var name: String
    var Tel: String
    var Mail: String
    var selectedFood: String
    var selectedProof: String
    var Remark: String
}


struct EventRegistration_Tab2_ListView: View {
    
    @ObservedObject var vm: EventRegistration_Tab2_ListViewModel
    // 註冊 callback
    var onDetailTapped: ((EventData_Apply) -> Void)? = nil
    var onModdingInfoTapped: ((EventData_Apply) -> Void)? = nil
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    
    var body: some View {
        VStack(alignment: .leading, spacing: isPad ? 19 : 10) {
            // 上層標題列
            HStack {
                Text(vm.event.name)
                    .font(.system(size: isPad ? 41 : 20, weight: .bold))
                    .foregroundColor(Color("Text_Color"))
                Spacer()
                Text(vm.event.department)
                    .font(.system(size: isPad ? 37 : 17))
                    .foregroundColor(Color.gray)
            }
            .padding(.horizontal, 11)
            // 主要內容容器
            VStack(alignment: .leading, spacing: 8) {
                // Header: 標題與狀態（可點擊切換展開）
                HStack {
                    Text("Event_Detail_Title")
                        .font(.system(size: isPad ? 33 : 19, weight: .bold))
                        .foregroundColor(Color(hex: "#297FCA"))
                    Spacer()
                    Text(vm.localizedStateText)
                        .font(.system(size: isPad ? 29 : 17))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 9).stroke(vm.stateColor, lineWidth: 1))
                        .foregroundColor(vm.stateColor)
                    // 箭頭符號
                    Text(vm.isExpanded ? " ˇ " : " ˆ ")
                        .font(.system(size: isPad ? 37 : 29))
                        .foregroundColor(Color(hex: "#297FCA"))
                        .baselineOffset(-13)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, isPad ? 15 : 1)
                .contentShape(Rectangle()) // 讓整個 HStack 可被點擊
                .onTapGesture { vm.toggleExpanded() }
                // 詳細欄位（展開時顯示）
                if vm.isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        EventInfoRow(icon: "info.circle.fill", label: "Event_ID", value: vm.event.eventSerialID)
                        EventInfoRow(icon: "calendar", label: "Event_Time", value: vm.event.eventTime)
                        EventInfoRow(icon: "mappin.and.ellipse", label: "Event_Location", value: vm.event.eventLocation)
                        EventInfoRow(icon: "person.2.fill", label: "Event_Reg_State", value: vm.event.state)
                        // 底部按鈕列
                        HStack(spacing: isPad ? 83 : 24) {
                            Button {
                                onDetailTapped?(vm.event) // 呼叫父層 callback
                            } label: {
                                Text("Event_BTN_Detail")
                                    .frame(width: isPad ? 159 : 90, height: isPad ? 53 : 37)
                                    .foregroundColor(.white)
                                    .background(Color(hex: "#292929"))
                                    .cornerRadius(31)
                            }

                            
                            if vm.event.event_state.contains("修改") {
                                Button {
                                    onModdingInfoTapped?(vm.event) // 呼叫父層 callback
                                } label: {
                                    Text("Event_ModInfo")
                                        .frame(width: isPad ? 259 : 180, height: isPad ? 53 : 37)
                                        .foregroundColor(.white)
                                        .background(Color(hex: "#292929"))
                                        .cornerRadius(31)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color("Linear_Inside"))
            .cornerRadius(11)
            .shadow(radius: 2)
            .padding(.horizontal, 11)
        }
        .padding(.vertical, 5)
        .background(Color("Linear"))
        Divider().background(Color(hex: "#D1D1D6")).padding(.vertical, 7)
    }
}
