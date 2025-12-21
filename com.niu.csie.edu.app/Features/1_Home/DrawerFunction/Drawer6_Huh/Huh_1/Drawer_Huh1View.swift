import SwiftUI



struct Drawer_Huh1View: View {
    
    @State private var selectedIndex: Int? = nil

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    // 直接在 View 裡建資料，不用 ViewModel
    private let features: [HuhFeature] = [
        HuhFeature(title: "EUNI",
            subtitle: "EUNI_",
            iconName: "\u{e809}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "EUNI_Page_0_1_Title", imageName: "Huh_EUNI_image1", description: "EUNI_Page_0_1_Message"),
                Huh2Page(title: "EUNI_Page_1_1_Title", imageName: "Huh_EUNI_image2", description: "EUNI_Page_1_1_Message"),
                Huh2Page(title: "EUNI_Page_2_1_Title", imageName: "Huh_EUNI_image3", description: "EUNI_Page_2_1_Message"),
                Huh2Page(title: "EUNI_Page_3_1_Title", imageName: "Huh_EUNI_image4", description: "EUNI_Page_3_1_Message"),
                Huh2Page(title: "EUNI_Page_4_1_Title", imageName: "Huh_EUNI_image5", description: "EUNI_Page_4_1_Message")
            ]
        ),
        HuhFeature(title: "Score_Inquiry",
            subtitle: "Score_Inquiry_",
            iconName: "\u{e801}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Score_Inquiry_Page_0_1_Title", imageName: "Huh_ScoreInquiry_image1", description: "Score_Inquiry_Page_0_1_Message"),
                Huh2Page(title: "Score_Inquiry_Page_1_1_Title", imageName: "Huh_ScoreInquiry_image2", description: "Score_Inquiry_Page_1_1_Message")
            ]
        ),
        HuhFeature(title: "Class_Schedule",
            subtitle: "Class_Schedule_",
            iconName: "\u{e803}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Class_Schedule_Page_0_1_Title", imageName: "Huh_ClassSchedule_image1", description: "Class_Schedule_Page_0_1_Message")
            ]
        ),
        HuhFeature(title: "Event_Registration",
            subtitle: "Event_Registration_",
            iconName: "\u{e80a}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Event_Registration_Page_0_1_Title", imageName: "Huh_EventRegistration_image1", description: "Event_Registration_Page_0_1_Message"),
                Huh2Page(title: "Event_Registration_Page_1_1_Title", imageName: "Huh_EventRegistration_image2", description: "Event_Registration_Page_1_1_Message"),
                Huh2Page(title: "Event_Registration_Page_2_1_Title", imageName: "Huh_EventRegistration_image3", description: "Event_Registration_Page_2_1_Message"),
                Huh2Page(title: "Event_Registration_Page_3_1_Title", imageName: "Huh_EventRegistration_image4", description: "Event_Registration_Page_3_1_Message")
            ]
        ),
        HuhFeature(title: "Contact_Us",
            subtitle: "Contact_Us_",
            iconName: "\u{e800}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Contact_Us_Page_0_1_Title", imageName: "Huh_ContactUs_image1", description: "Contact_Us_Page_0_1_Message"),
                Huh2Page(title: "Contact_Us_Page_1_1_Title", imageName: "Huh_ContactUs_image2", description: "Contact_Us_Page_1_1_Message")
            ]
        ),
        HuhFeature(title: "Graduation_Threshold",
            subtitle: "Graduation_Threshold_",
            iconName: "\u{e802}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Graduation_Threshold_Page_0_1_Title", imageName: "Huh_GraduationThreshold_image1", description: "Graduation_Threshold_Page_0_1_Message"),
                Huh2Page(title: "Graduation_Threshold_Page_1_1_Title", imageName: "Huh_GraduationThreshold_image2", description: "Graduation_Threshold_Page_1_1_Message"),
                Huh2Page(title: "Graduation_Threshold_Page_2_1_Title", imageName: "Huh_GraduationThreshold_image3", description: "Graduation_Threshold_Page_2_1_Message")
            ]
        ),
        HuhFeature(title: "Subject_System",
            subtitle: "Subject_System_",
            iconName: "\u{e807}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Subject_System_Page_0_1_Title", imageName: "Huh_SubjectSystem_image1", description: "Subject_System_Page_0_1_Message")
            ]
        ),
        HuhFeature(title: "Bus",
            subtitle: "Bus_",
            iconName: "\u{e806}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Bus_Page_0_1_Title", imageName: "Huh_Bus_image1", description: "Bus_Page_0_1_Message"),
                Huh2Page(title: "Bus_Page_1_1_Title", imageName: "Huh_Bus_image2", description: "Bus_Page_1_1_Message")
            ]
        ),
        HuhFeature(title: "Zuvio",
            subtitle: "Zuvio_",
            iconName: "\u{e804}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Zuvio_Page_0_1_Title", imageName: "Huh_Zuvio_image1", description: "Zuvio_Page_0_1_Message"),
                Huh2Page(title: "Zuvio_Page_1_1_Title", imageName: "Huh_Zuvio_image2", description: "Zuvio_Page_1_1_Message")
            ]
        ),
        HuhFeature(title: "Take_Leave",
            subtitle: "Take_Leave",
            iconName: "person.fill.xmark",
            isSystemIcon: true,
            pages: [
                Huh2Page(title: "Take_Leave_Page_0_1_Title", imageName: "Huh_TakeLeave_image1", description: "Take_Leave_Page_0_1_Message")
            ]
        )/*,
        HuhFeature(title: "Mail",
            subtitle: "Mail_",
            iconName: "\u{e808}",
            isSystemIcon: false,
            pages: [
                Huh2Page(title: "Mail_Page_0_1_Title", imageName: "Huh_Mail_image1", description: "Mail_Page_0_1_Message")
            ]
        )*/
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: isPad ? 13 : 7) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        NavigationLink {
                            Drawer_Huh2View(title: feature.title, feature: feature)
                        } label: {
                            Drawer_Huh1_ListView(feature: feature, index: index)
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Linear").ignoresSafeArea())
        /*
        .toolbarBackground(.visible, for: .navigationBar) // 強制背景顯示
        .toolbarBackground(Color.accentColor, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)*/
    }
}
