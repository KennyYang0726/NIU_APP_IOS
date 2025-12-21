// RootView.swift
import SwiftUI


struct RootView: View {
    // @StateObject var appState = AppState()
    @EnvironmentObject var appState: AppState
    // 只有 ipad 要套用這個 canvas
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    @ViewBuilder
    func currentView() -> some View {
        switch appState.route {
        case .login:
            LoginView().environmentObject(appState)
        case .home:
            DrawerManagerView().environmentObject(appState)
        case .EUNI:
            EUNI1View().environmentObject(appState)
        case .EUNI2:
            EUNI2View().environmentObject(appState)
        case .Score_Inquiry:
            ScoreInquiryTabView().environmentObject(appState)
        case .Class_Schedule:
            ClassScheduleView().environmentObject(appState)
        case .Event_Registration:
            EventRegistrationTabView().environmentObject(appState)
        case .Contact_Us:
            ContactUsTabView().environmentObject(appState)
        case .Graduation_Threshold:
            GraduationThresholdView().environmentObject(appState)
        case .Subject_System:
            SubjectSystemView().environmentObject(appState)
        case .Bus:
            BusView().environmentObject(appState)
        case .ZUVIO:
            ZuvioView().environmentObject(appState)
        case .Take_Leave:
            TakeLeaveView().environmentObject(appState)
        case .Mail:
            MailView().environmentObject(appState)
        }
    }
    
    var body: some View {
        /*
        ZStack {
            currentView()
                .id(appState.route)
                .transition(transitionFor(appState.navAnimation))
        }*/
        let mainContent =
            ZStack {
                currentView()
                    .id(appState.route)
                    .transition(transitionFor(appState.navAnimation))
            }
        // ipad 把整個 app content 放進 PortraitCanvas
        Group {
            if isPad {
                PortraitCanvas(backgroundColor: .black) {
                    mainContent
                }
            } else {
                mainContent
            }
        }
        .toast(isPresented: Binding(
            get: { appState.toastMessage != nil },
            set: { if !$0 { appState.toastMessage = nil } }
        )) {
            if let message = appState.toastMessage {
                Text(message)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
            }
        }
    }
    
    func transitionFor(_ anim: NavigationAnimation) -> AnyTransition {
        switch anim {
        case .slideLeft:
            // 新頁面從右邊進來，舊頁面往左移出
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .slideRight:
            // 新頁面從左邊進來，舊頁面往右移出
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }
    
}
