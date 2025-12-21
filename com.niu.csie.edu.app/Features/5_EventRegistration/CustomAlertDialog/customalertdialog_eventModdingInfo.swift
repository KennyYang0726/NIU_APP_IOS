import SwiftUI



// MARK: - 單選選項列舉
enum ModRadio1: String, CaseIterable, Identifiable {
    case r1_1 = "1"
    case r1_2 = "2"
    case r1_3 = "3"
    var id: String { self.rawValue }
    var title: LocalizedStringKey { // 第一組三選一 (用餐選項)
        switch self {
        case .r1_1: return "Event_ModInfo_Radio1_1"
        case .r1_2: return "Event_ModInfo_Radio1_2"
        case .r1_3: return "Event_ModInfo_Radio1_3"
        }
    }
}

enum ModRadio2: String, CaseIterable, Identifiable {
    case r2_1 = "1"
    case r2_2 = "2"
    var id: String { self.rawValue }
    var title: LocalizedStringKey { // 第二組二選一 (參與證明)
        switch self {
        case .r2_1: return "Event_ModInfo_Radio2_1"
        case .r2_2: return "Event_ModInfo_Radio2_2"
        }
    }
}

// MARK: - 主體 View
struct customalertdialog_eventModdingInfo: View {
    // 顯示資料
    let title: LocalizedStringKey = "Event_ModInfo"
    let role: String
    let klass: String
    let studentNo: String
    let name: String
    
    // 傳入初始值，而不是 Binding
    let initialTel: String
    let initialMail: String
    let initialRemark: String
    let initialselectedFood: String
    let initialSelectedProof: String

    // Dialog 內部管理可編輯狀態
    @State private var tel: String = ""
    @State private var mail: String = ""
    @State private var remark: String = ""
    // 單選按鈕
    @State private var radio1: ModRadio1 = .r1_1
    @State private var radio2: ModRadio2 = .r2_1

    // 動作
    let onCancel: () -> Void
    let onSave: (_ tel: String, _ mail: String, _ remark: String, _ r1: ModRadio1, _ r2: ModRadio2) -> Void

    @Environment(\.colorScheme) private var scheme
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    

    init(role: String,
         klass: String,
         studentNo: String,
         name: String,
         initialTel: String,
         initialMail: String,
         initialRemark: String,
         initialselectedFood: String,
         initialSelectedProof: String,
         onCancel: @escaping () -> Void,
         onSave: @escaping (_ tel: String, _ mail: String, _ remark: String, _ radio1: ModRadio1, _ radio2: ModRadio2) -> Void) {
            self.role = role
            self.klass = klass
            self.studentNo = studentNo
            self.name = name
            self.initialTel = initialTel
            self.initialMail = initialMail
            self.initialRemark = initialRemark
            self.initialselectedFood = initialselectedFood
            self.initialSelectedProof = initialSelectedProof
            self.onCancel = onCancel
            self.onSave = onSave

            // 初始化 State
            _tel = State(initialValue: initialTel)
            _mail = State(initialValue: initialMail)
            _remark = State(initialValue: initialRemark)
            _radio1 = State(initialValue: ModRadio1(rawValue: initialselectedFood) ?? .r1_1)
            _radio2 = State(initialValue: ModRadio2(rawValue: initialSelectedProof) ?? .r2_1)
         }


    var body: some View {
        let P = DialogPalette(scheme)

        ZStack {
            // 半透明背景
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 0) {
                // ====== 標題列 ======
                Text(title)
                    .font(.system(size: isPad ? 26 : 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isPad ? 14 : 10)
                    .padding(.horizontal, isPad ? 11 : 7)
                    .background(P.titleBG)
                    .clipShape(RoundedCornerShape(radius: isPad ? 18 : 12, corners: [.topLeft, .topRight]))

                // ====== 白色內容區 ======
                VStack(alignment: .leading, spacing: isPad ? 24 : 14) {

                    // ---- 基本資料表格 ----
                    TableBox {
                        VStack(spacing: 0) {
                            TableRow("Event_ModInfo_role") { Text(role) }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_ModInfo_class") { Text(klass) }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_ModInfo_schnum") { Text(studentNo) }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_ModInfo_name") { Text(name) }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_ModInfo_tel") {
                                TextField("", text: $tel)
                                    .keyboardType(.phonePad)
                            }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_ModInfo_mail") {
                                TextField("", text: $mail)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                            }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_ModInfo_remark") {
                                TextField("", text: $remark, axis: .vertical)
                                    .lineLimit(1...3)
                            }
                        }
                        .padding(.horizontal, isPad ? 20 : 12)
                        .padding(.vertical, isPad ? 20 : 12)
                    }

                    // ---- 單選群組 ----
                    VStack(alignment: .leading, spacing: isPad ? 12 : 8) {
                        Text("Event_ModInfo_RadioTextTitle")
                            .font(.system(size: isPad ? 22 : 13))
                            .foregroundColor(Color("Text_Color"))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, isPad ? 6 : 2)

                        Text("Event_ModInfo_RadioTextMessage1")
                            .font(.system(size: isPad ? 21 : 14))
                            .foregroundColor(Color("Text_Color"))
                            .padding(.horizontal, isPad ? 20 : 13)

                        HStack(spacing: isPad ? 40 : 20) {
                            ForEach(ModRadio1.allCases) { opt in
                                RadioButton(
                                    isOn: Binding(
                                        get: { radio1 == opt },
                                        set: { _ in radio1 = opt }
                                    ),
                                    label: opt.title,
                                    isPad: isPad
                                )
                            }
                        }
                        .padding(.horizontal, isPad ? 50 : 29)

                        Text("Event_ModInfo_RadioTextMessage2")
                            .font(.system(size: isPad ? 21 : 14))
                            .foregroundColor(Color("Text_Color"))
                            .padding(.horizontal, isPad ? 20 : 13)
                            .padding(.top, isPad ? 8 : 3)

                        HStack(spacing: isPad ? 40 : 20) {
                            ForEach(ModRadio2.allCases) { opt in
                                RadioButton(
                                    isOn: Binding(
                                        get: { radio2 == opt },
                                        set: { _ in radio2 = opt }
                                    ),
                                    label: opt.title,
                                    isPad: isPad
                                )
                            }
                        }
                        .padding(.horizontal, isPad ? 50 : 29)
                        .padding(.bottom, isPad ? 30 : 24)
                    }

                    // ---- 按鈕列 ----
                    HStack(spacing: isPad ? 22 : 16) {
                        Button(action: onCancel) {
                            Text("Event_ModInfo_btn1")
                                .font(.system(size: isPad ? 23 : 14))
                                .padding(isPad ? 17 : 11)
                        }
                        .buttonStyle(DialogButtonStyle(bg: Color(hex:"#942320"), fg: .white))

                        Button {
                            onSave(tel, mail, remark, radio1, radio2)
                        } label: {
                            Text("Event_ModInfo_btn2")
                                .font(.system(size: isPad ? 23 : 14))
                                .padding(isPad ? 17 : 11)
                        }
                        .buttonStyle(DialogButtonStyle(bg: P.buttonBlue, fg: .white))
                    }
                    .frame(maxWidth: .infinity, alignment: .center) // 水平置中
                    .padding(.horizontal, isPad ? 100 : 40)
                    .padding(.bottom, isPad ? 10 : 6)
                }
                .padding(isPad ? 32 : 20)
                .background(P.cardBG)
                .clipShape(RoundedCornerShape(radius: isPad ? 18 : 12, corners: [.bottomLeft, .bottomRight]))
            }
            .frame(maxWidth: isPad ? 700 : 640)
            .shadow(radius: isPad ? 30 : 20)
            .padding(.horizontal, isPad ? 40 : 20)
        }
    }
}

// MARK: - Radio Button
private struct RadioButton: View {
    @Binding var isOn: Bool
    let label: LocalizedStringKey
    let isPad: Bool

    var body: some View {
        HStack(spacing: isPad ? 12 : 6) {
            Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                .font(.system(size: isPad ? 25 : 16))
                .foregroundColor(Color("BG_Color"))
            
            Text(label)
                .font(.system(size: isPad ? 21 : 13))
                .foregroundColor(Color("Text_Color"))
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn = true }
    }
}

#Preview {
    customalertdialog_eventModdingInfo(
        role: "學生",
        klass: "資訊工程所",
        studentNo: "B12345678",
        name: "王小明",
        initialTel: "0912345678",
        initialMail: "test@mail.com",
        initialRemark: "這是備註",
        initialselectedFood: "1",
        initialSelectedProof: "2",
        onCancel: {},
        onSave: { _,_,_,_,_ in }
    )
    .preferredColorScheme(.light)
}
