import SwiftUI

struct customalertdialog_eventDetail: View {
    // 顯示資料
    let title: String
    let eventID: String
    let eventTime: String
    let eventLocation: String
    let eventDetail: String
    let department: String
    let contactName: String
    let contactTel: String
    let contactMail: String
    let link: String
    let remark: String
    let factorAuth: String
    let registerTime: String

    let okText: LocalizedStringKey
    let onOK: () -> Void

    @Environment(\.colorScheme) private var scheme
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        let P = DialogPalette(scheme)

        ZStack {
            // 半透明背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()

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
                VStack(alignment: .leading, spacing: isPad ? 24 : 16) {
                    TableBox {
                        VStack(spacing: 0) {
                            TableRow("Event_ID") { Text(eventID)}
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_Time") { Text(eventTime)
                                .fixedSize(horizontal: false, vertical: true)}
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_Location") { Text(eventLocation)}
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_Detail") {
                                ScrollView(.vertical, showsIndicators: true) {
                                    Text(eventDetail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.trailing, 6)
                                        .font(.system(size: isPad ? 23 : 14))
                                }
                                .frame(height: isPad ? 130 : 79)
                            }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_Department") { Text(department)}
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_ContactInfo") {
                                VStack(alignment: .leading, spacing: isPad ? 10 : 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.fill")
                                        Text(contactName)
                                            .font(.system(size: isPad ? 23 : 14))
                                    }
                                    HStack(spacing: 6) {
                                        Image(systemName: "phone.fill")
                                        Text(contactTel)
                                            .font(.system(size: isPad ? 23 : 14))
                                    }
                                    HStack(spacing: 6) {
                                        Image(systemName: "envelope.fill")
                                        Text(contactMail)
                                            .font(.system(size: isPad ? 23 : 14))
                                            .foregroundColor(.blue) // 讓使用者知道可點
                                            .underline()
                                            .onTapGesture {
                                                let subject = "【活動詢問】\(title)"
                                                let body = "您好，我想詢問關於活動「\(title)」的相關事項。"
                                                if let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                                                    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                                                    let url = URL(string: "mailto:\(contactMail)?subject=\(encodedSubject)&body=\(encodedBody)") {
                                                    if UIApplication.shared.canOpenURL(url) {
                                                        UIApplication.shared.open(url)
                                                    } else {
                                                        print("無法開啟郵件應用程式")
                                                    }
                                                } else {
                                                    print("郵件 URL 編碼失敗")
                                                }
                                            }
                                    }
                                }
                                .font(.system(size: isPad ? 19 : 13))
                            }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_Link") {
                                Text(link)
                                    .foregroundColor(.blue) // 讓使用者知道可點
                                    .underline()
                                    .onTapGesture {
                                        if let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            if UIApplication.shared.canOpenURL(url) {
                                                UIApplication.shared.open(url)
                                            } else {
                                                print("無法開啟瀏覽器，URL：\(link)")
                                            }
                                        } else {
                                            print("URL 格式錯誤：\(link)")
                                        }
                                    }
                            }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_Remark") {
                                ScrollView(.vertical, showsIndicators: true) {
                                    Text(remark)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.trailing, 6)
                                        .font(.system(size: isPad ? 23 : 14))
                                }
                                .frame(height: isPad ? 120 : 71)
                            }
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_factor_authentication") { Text(factorAuth)}
                            Divider().background(Color("Text_Color"))

                            TableRow("Event_RegisterTime") { Text(registerTime)}
                        }
                        .padding(.horizontal, isPad ? 20 : 12)
                        .padding(.vertical, isPad ? 20 : 12)
                    }

                    Button(action: onOK) {
                        Text(okText)
                            .frame(maxWidth: .infinity)
                            .frame(height: isPad ? 64 : 40)
                            .font(.system(size: isPad ? 29 : 17, weight: .semibold))
                    }
                    .buttonStyle(DialogButtonStyle(bg: P.buttonBlue, fg: .white))
                    .padding(.horizontal, isPad ? 140 : 60)
                    .padding(6)
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
