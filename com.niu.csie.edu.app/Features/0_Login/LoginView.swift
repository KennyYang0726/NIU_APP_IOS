import SwiftUI


/// 負責 UI 呈現，邏輯交由 ViewModel 控制
struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @EnvironmentObject var drawerVM: DrawerManagerViewModel
    @EnvironmentObject var appState: AppState // 注入狀態
        
    var body: some View {
        let metrics = LayoutMetrics.metrics(for: hSizeClass ?? .compact)
        // 登入流程 (WebView + Toast)
        // 包在 ZStack 懸浮才不會把上方 logo 擠出去
        ZStack {
            if vm.startSSOLoginProcess {
                SSOLoginWebView(
                    account: vm.loginAccount,
                    password: vm.password
                ) { result in
                    vm.handleSSOLoginResult(result)
                }
                .frame(width: 300, height: 300)
                .offset(x: UIScreen.main.bounds.width * 2)
            }
            if vm.startZuvioLoginProcess {
                ZuvioLoginWebView(
                    account: vm.zuvioLoginEmail,
                    password: vm.password
                ) { success in
                    vm.handleZuvioLoginResult(success)
                }
                .frame(width: 300, height: 300)
                .offset(x: UIScreen.main.bounds.width * 2)
                //.frame(height: 300)
            }
        }
        VStack(spacing: metrics.mainSpacing) {
            // Logo
            Image("niu_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.horizontal, metrics.logoHorizontalPadding)
            
            // App 名稱
            Text(LocalizedStringKey("app_name"))
                .font(.system(size: metrics.titleFont))
                .scaledToFit()
                .foregroundColor(Color("Title"))
            
            // 表單區塊
            VStack(spacing: metrics.innerSpacing) {
                
                // 帳號輸入
                HStack {
                    SFIcon(name: "person.fill",
                           width: metrics.innerIconWidth,
                           height: metrics.innerIconHeight)
                    
                    TextField("",
                              text: $vm.account,
                              prompt: Text(LocalizedStringKey("school_num"))
                                .foregroundColor(.gray))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .frame(height: metrics.textFieldHeight)
                        .font(.system(size: metrics.textFieldHeight - metrics.innerIconWidth))
                        .padding(.leading, metrics.innerPaddingLeft)
                        .foregroundColor(.black)
                }
                .modifier(InputFieldModifier(height: metrics.textFieldHeight,
                                             sidePadding: metrics.innerSpacing))
                
                // 密碼輸入
                HStack {
                    SFIcon(name: "key.fill",
                           width: metrics.innerIconWidth,
                           height: metrics.innerIconHeight)
                    
                    ZStack {
                        if vm.isPasswordVisible {
                            TextField("",
                                      text: $vm.password,
                                      prompt: Text(LocalizedStringKey("pwd"))
                                        .foregroundColor(.gray))
                        } else {
                            SecureField("",
                                        text: $vm.password,
                                        prompt: Text(LocalizedStringKey("pwd"))
                                          .foregroundColor(.gray))
                        }
                    }
                    .textContentType(.password)
                    .frame(height: metrics.textFieldHeight)
                    .font(.system(size: metrics.textFieldHeight - metrics.innerIconWidth))
                    .padding(.leading, metrics.innerPaddingLeft)
                    .foregroundColor(.black)
                    
                    // 顯示/隱藏密碼
                    SFIcon(name: vm.isPasswordVisible ? "eye.fill" : "eye.slash.fill",
                           width: metrics.innerIconWidth * 1.5,
                           height: metrics.innerIconHeight)
                        .onTapGesture { vm.togglePasswordVisible() }
                }
                .modifier(InputFieldModifier(height: metrics.textFieldHeight,
                                             sidePadding: metrics.innerSpacing))
                
                // 登入按鈕
                Button {
                    vm.onTapLogin()
                } label: {
                    Text(LocalizedStringKey("btn_login"))
                        .font(.system(size: metrics.textFieldHeight - metrics.innerIconWidth))
                        .padding(11)
                        .frame(maxWidth: .infinity)
                }
                .background(
                    RoundedRectangle(cornerRadius: 40).foregroundColor(Color("Btn_Color"))
                )
                .padding(.horizontal, metrics.titleFont)
                .padding(.top, metrics.innerSpacing)
                .foregroundColor(.white)
            }
            .padding(23)
            .background(RoundedRectangle(cornerRadius: 23).foregroundColor(Color("Linear")))
        }
        .padding(metrics.mainPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("BG_Color"))
        // 登入中 prog (注意！放在這裡才是全版面)
        .overlay(
            ProgressOverlay(isVisible: $vm.showOverlay, text: vm.overlayText)
        )
        .onAppear {
            // 先把所有可能影響登入的狀態重置
            vm.resetForFreshAttempt()
            // 自動登入邏輯觸發
            vm.autoLogin()
        }
        
        // === Alert 與 Toast 移到這裡 ===
        .alert(item: $vm.LoginActiveAlert) { which in
            switch which {
            case .emptyFields:
                return Alert(title: Text(LocalizedStringKey("Dialog_Error_Title")),
                             message: Text(LocalizedStringKey("Dialog_Error_EmptyField")),
                             dismissButton: .default(Text(LocalizedStringKey("Dialog_OK"))))
            case .loginFailed: // 已被 sso dialog 取代，不會觸發這個
                return Alert(title: Text(LocalizedStringKey("login_failed_title")),
                             message: Text(LocalizedStringKey("login_failed_message")),
                             dismissButton: .default(Text(LocalizedStringKey("Dialog_OK"))))
            // === 版本更新 ===
            case .newVersion(let message):
                return Alert(title: Text(LocalizedStringKey("New_Version_Found")),
                                message: Text(message),
                                primaryButton: .default(Text(LocalizedStringKey("New_Version_OK"))) {
                                    vm.handleUpdateAction()
                                },
                                secondaryButton: .cancel(Text(LocalizedStringKey("New_Version_Cancel"))) {
                                    // Drawer 所在頁面重置，避免進入錯誤畫面
                                    drawerVM.currentPage = .home
                                    drawerVM.isDrawerOpen = false
                                    // 重置後再跳頁，確認無誤
                                    appState.navigate(to: .home, withToast: LocalizedStringKey("login_success"))
                                })
            // === SSO：完全比照 Android 情境 ===
            case .ssoCredentialsFailed(let message):
                return Alert(title: Text(LocalizedStringKey("login_failed_title")),
                                message: Text(message),
                                dismissButton: .default(Text(LocalizedStringKey("Dialog_OK"))) {
                                    vm.startSSOLoginProcess = false
                                })
            case .ssoPasswordExpiring(let message):
                return Alert(title: Text(LocalizedStringKey("Dialog_PWD_almost_expired_Title")),
                                message: Text(message),
                                primaryButton: .default(Text(LocalizedStringKey("Dialog_ChangePWD"))) {
                                    vm.openSSOPasswordChange()
                                },
                                secondaryButton: .cancel(Text(LocalizedStringKey("Dialog_ChangePWDLater"))) {
                                    vm.resumeSSOAfterClosingSweetAlert?()
                                })
            case .ssoPasswordExpired(let message):
                return Alert(title: Text(LocalizedStringKey("Dialog_PWD_expired_Title")),
                                message: Text(message),
                                dismissButton: .default(Text(LocalizedStringKey("Dialog_ChangePWD"))) {
                                    vm.openSSOPasswordChange()
                                })
            case .ssoAccountLocked(let lockTime):
                let messageText: String = lockTime ?? NSLocalizedString(
                        "Dialog_AccountLocked_Default_Message",
                        comment: "\n安全起見\n15分鐘內不得登入"
                    )
                return Alert(title: Text(LocalizedStringKey("Dialog_AccountLocked_Title")),
                                message: Text(messageText),
                                dismissButton: .default(Text(LocalizedStringKey("Dialog_OK"))) {
                                    vm.startSSOLoginProcess = false
                                    vm.showOverlay = false
                                })
            case .ssoSystemError:
                return Alert(title: Text(LocalizedStringKey("Dialog_SystemError_Title")),
                                message: Text(LocalizedStringKey("Dialog_SystemError_Message")),
                                dismissButton: .default(Text(LocalizedStringKey("Dialog_OK"))) {
                                    vm.startSSOLoginProcess = false
                                    vm.showOverlay = false
                                })
            case .ssoGeneric(let title, let message):
                return Alert(title: Text(title),
                                message: Text(message),
                                dismissButton: .default(Text(LocalizedStringKey("Dialog_OK"))) {
                                    vm.startSSOLoginProcess = false
                                    vm.showOverlay = false
                                })
            }
        }
        // 等兩邊流程都「完成」再判斷是否雙成功，成功才跳頁
        .onChange(of: vm.loginFinished) { finished in
            guard finished else { return }
            if vm.zuvioLoginSuccess && vm.ssoLoginSuccess {
                // 檢查版本
                vm.checkAppVersionThenProceed {
                    // 只有「沒有新版本」才會跑到這
                    drawerVM.currentPage = .home
                    drawerVM.isDrawerOpen = false
                    appState.navigate(
                        to: .home,
                        withToast: LocalizedStringKey("login_success")
                    )
                }
            }
        }
    }
}

// MARK: - 共用子元件
private struct SFIcon: View {
    let name: String
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        Image(systemName: name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.gray)
            .frame(width: width, height: height)
    }
}

private struct InputFieldModifier: ViewModifier {
    let height: CGFloat
    let sidePadding: CGFloat
    func body(content: Content) -> some View {
        content
            .frame(height: height)
            .padding(.leading, sidePadding)
            .padding(.trailing, sidePadding)
            .background(Color("Input_Field"))
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}

// MARK: - 版面參數
private struct LayoutMetrics {
    let mainSpacing: CGFloat
    let mainPadding: EdgeInsets
    let logoHorizontalPadding: CGFloat
    let titleFont: CGFloat
    let innerSpacing: CGFloat
    let innerIconWidth: CGFloat
    let innerIconHeight: CGFloat
    let innerPaddingLeft: CGFloat
    let textFieldHeight: CGFloat
    
    static func metrics(for sizeClass: UserInterfaceSizeClass) -> LayoutMetrics {
        let screenHeight = UIScreen.main.bounds.height
        switch sizeClass {
        case .compact: // iPhone
            return .init(
                mainSpacing: 19,
                mainPadding: EdgeInsets(
                    top: screenHeight * 0.07,
                    leading: 19,
                    bottom: 0,
                    trailing: 19),
                logoHorizontalPadding: 111,
                titleFont: 37,
                innerSpacing: 11,
                innerIconWidth: 19,
                innerIconHeight: 23,
                innerPaddingLeft: 7,
                textFieldHeight: 37
            )
        default:       // iPad
            return .init(
                mainSpacing: 37,
                mainPadding: EdgeInsets(
                    top: screenHeight * 0.05,
                    leading: 127,
                    bottom: 0,
                    trailing: 127),
                logoHorizontalPadding: 167,
                titleFont: 71,
                innerSpacing: 23,
                innerIconWidth: 29,
                innerIconHeight: 47,
                innerPaddingLeft: 11,
                textFieldHeight: 73
            )
        }
    }
}
