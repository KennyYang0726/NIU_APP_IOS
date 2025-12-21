import SwiftUI


// BugReport
struct ContactUs_Tab2_View: View {
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm = ContactUs_Tab2_ViewModel()
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    

    var body: some View {
        ScrollView {
            VStack(spacing: isPad ? 53 : 30) {
                // === 說明區塊 ===
                VStack(spacing: isPad ? 44 : 16) {
                    Text(LocalizedStringKey("BugReported_text"))
                        .font(.system(size: isPad ? 41 : 23))
                        .foregroundColor(.primary)
                }
                .padding(isPad ? 30 : 20) // 內部間距一致
                .frame(maxWidth: .infinity) // 區塊撐滿
                .background(
                    RoundedRectangle(cornerRadius: 23)
                        .foregroundColor(Color("Linear_Inside"))
                )
                // 小一點的spacing的VStack塞中間內容
                VStack(spacing: isPad ? 33 : 19) {
                    // BugType 欄位
                    VStack(spacing: isPad ? 23 : 11) {
                        HStack { // 靠左對齊 + Spacer
                            Spacer()
                            Text(LocalizedStringKey("Bug_Report_text1"))
                                .font(.system(size: isPad ? 41 : 23))
                                .foregroundColor(Color("Text_Color"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        TextEditor(text: $vm.BugType)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: isPad ? 91 : 67)
                            .background(Color("Input_Field"))
                            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .foregroundColor(Color.black)
                            .font(.system(size: isPad ? 41 : 23))
                            .scrollContentBackground(.hidden) // 移除原生 TextEditor 背景
                            .overlay(
                                // 提示文字 (Hint)
                                Group {
                                    if vm.BugType.isEmpty {
                                        Text(LocalizedStringKey("Bug_Report_input1"))
                                            .foregroundColor(Color.gray)
                                            .padding(.horizontal, 22)
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .font(.system(size: isPad ? 41 : 23))
                                    }
                                }
                            )
                    }
                    // BugDescription 欄位
                    VStack(spacing: isPad ? 23 : 11) {
                        HStack { // 靠左對齊 + Spacer
                            Spacer()
                            Text(LocalizedStringKey("Bug_Report_text2"))
                                .font(.system(size: isPad ? 41 : 23))
                                .foregroundColor(Color("Text_Color"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        TextEditor(text: $vm.BugDescription)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: isPad ? 91 : 67)
                            .background(Color("Input_Field"))
                            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .foregroundColor(Color.black)
                            .font(.system(size: isPad ? 41 : 23))
                            .scrollContentBackground(.hidden) // 移除原生 TextEditor 背景
                            .overlay(
                                // 提示文字 (Hint)
                                Group {
                                    if vm.BugDescription.isEmpty {
                                        Text(LocalizedStringKey("Bug_Report_input2"))
                                            .foregroundColor(Color.gray)
                                            .padding(.horizontal, 22)
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .font(.system(size: isPad ? 41 : 23))
                                    }
                                }
                            )
                    }
                }
                // 勾選 + 送出按鈕區塊
                HStack {
                    Toggle(isOn: $vm.isSendingDeviceInfoChecked) {
                        Text(LocalizedStringKey("DeviceInfoReport"))
                            .font(.system(size: isPad ? 41 : 23))
                            .foregroundColor(.primary)
                    }
                    .toggleStyle(CheckboxStyle(size: isPad ? 41 : 23))
                    .frame(maxWidth: .infinity, alignment: .leading) // 相當於 weight=1

                    Button(action: {
                        vm.submitBugReport()
                    }) {
                        Text(LocalizedStringKey("Submit"))
                            .font(.system(size: isPad ? 41 : 23))
                            .foregroundColor(.white)
                            .frame(height: isPad ? 71 : 41)
                            .padding(.horizontal, isPad ? 50 : 23)
                            .background(
                                RoundedRectangle(cornerRadius: 41)
                                    .foregroundColor(Color("BG_Color"))
                            )
                    }
                }
                // HStack 左右內距
                .padding(.horizontal, isPad ? 59 : 19)
                // 移出畫面外的 Webview
                ZStack {
                    WebViewContainer(webView: vm.webProvider.webView)
                        .frame(width: 50, height: 50)
                        .offset(x: UIScreen.main.bounds.width * 2)
                }
            }
            .padding(isPad ? 40 : 20)
        }
        .onAppear {
            // 注入全域 appState(跳頁)
            vm.appState = appState
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Linear").ignoresSafeArea()) // 全域底色
        .toast(isPresented: $vm.showToast) {
            Text(LocalizedStringKey("EmptyContent"))
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
        }
    }
}
