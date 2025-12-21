import SwiftUI



struct GraduationThresholdView: View {
    
    @EnvironmentObject var appState: AppState // 注入狀態
    
    @StateObject private var vm = GraduationThresholdViewModel()
        
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    public var body: some View {
        AppBar_Framework(title: "Graduation_Threshold") {
            ZStack {
                // 這裡「只放一個主內容」，用 if 切換
                if vm.isWebVisible {
                    // 全版面 WebView
                    WebViewContainer(webView: vm.webProvider.webView)
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else if vm.canShowWeb {
                    // 全版面 Scroll UI
                    ScrollView {
                        VStack(spacing: isPad ? 31 : 17) {
                            if let data = vm.graduationData {
                                // 第一層 VStack (時數)
                                VStack {
                                    Text(LocalizedStringKey("Diverse_Hours"))
                                        .font(.system(size: isPad ? 37 : 22).bold())
                                        .padding(.top, 11)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 10)
                                    VStack(spacing: isPad ? 11 : 5) {
                                        let d = data.diverseHours
                                        // 服務
                                        DiverseHoursRow(title: "Diverse_Hours_Services", current: d[0], total: d[1], isPad: isPad)
                                        // 多元
                                        DiverseHoursRow(title: "Diverse_Hours_Diverse",  current: d[2], total: d[3], isPad: isPad)
                                        // 專業
                                        DiverseHoursRow(title: "Diverse_Hours_Major",    current: d[4], total: d[5], isPad: isPad)
                                        // 綜合
                                        DiverseHoursRow(title: "Diverse_Hours_Complex",  current: d[6], total: d[7], isPad: isPad)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 23)
                                            .foregroundColor(Color("Linear_Inside2"))
                                        )
                                }
                                .padding(.horizontal, isPad ? 9 : 5)
                                .padding(.bottom, isPad ? 17 : 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 23)
                                        .foregroundColor(Color("Linear_Inside"))
                                )
                                // 第二層 HStack (英語能力)
                                HStack {
                                    Text(LocalizedStringKey("English_Ability"))
                                        .font(.system(size: isPad ? 37 : 22).bold())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 10)
                                    Spacer()
                                    Text(data.englishAbility)
                                        .font(.system(size: isPad ? 37 : 22))
                                        .foregroundColor(vm.textColor(for: data.englishAbility))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.trailing, 10)
                                }
                                .padding(isPad ? 29 : 15)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 43)
                                        .foregroundColor(Color("Linear_Inside"))
                                    )
                                // 第三層 HStack (體適能)
                                HStack {
                                    Text(LocalizedStringKey("Physical_Fitness"))
                                        .font(.system(size: isPad ? 37 : 22).bold())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 10)
                                    Spacer()
                                    Text(data.physicalFitness)
                                        .font(.system(size: isPad ? 37 : 22))
                                        .foregroundColor(vm.textColor(for: data.physicalFitness))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.trailing, 10)
                                }
                                .padding(isPad ? 29 : 15)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 43)
                                        .foregroundColor(Color("Linear_Inside"))
                                    )
                                // 第四層 HStack (應修學分總數)
                                HStack {
                                    let d1 = data.creditRequired
                                    Text(LocalizedStringKey("Total_Credits_Required"))
                                        .font(.system(size: isPad ? 37 : 22).bold())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 10)
                                    Spacer()
                                    Text("\(d1[1])/\(d1[0])")
                                        .font(.system(size: isPad ? 37 : 22))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.trailing, 10)
                                }
                                .padding(isPad ? 29 : 15)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 43)
                                        .foregroundColor(Color("Linear_Inside"))
                                    )
                                // 第五層 HStack (學分學程)
                                HStack {
                                    Text(LocalizedStringKey("Credit_Course"))
                                        .font(.system(size: isPad ? 37 : 22).bold())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 10)
                                    Spacer()
                                    if (data.creditCourse.count < 4) {
                                        Text(LocalizedStringKey("Credit_Course_None"))
                                            .font(.system(size: isPad ? 37 : 22))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .padding(.trailing, 10)
                                    } else {
                                        let formattedValue = data.creditCourse.replacingOccurrences(of: "、", with: "\n")
                                        Text(formattedValue)
                                            .font(.system(size: isPad ? 29 : 17))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .padding(.trailing, 10)
                                    }
                                }
                                .padding(isPad ? 29 : 15)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 43)
                                        .foregroundColor(Color("Linear_Inside"))
                                    )
                            }
                            
                            
                        }
                        .padding(.vertical, isPad ? 32 : 20)
                        .padding(.horizontal, isPad ? 32 : 20)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .background(Color("Linear").ignoresSafeArea())
                }
                // 蓋在最上層的 loading overlay
                ProgressOverlay(isVisible: $vm.isOverlayVisible, text: vm.overlayText)
            }
            // 返回手勢攔截
            .background(
                NavigationSwipeHijacker(
                    handleSwipe: {
                        appState.navigate(to: .home)
                        return false
                    }
                )
            )
            // 右上角按鈕切換
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if vm.canShowWeb {
                            vm.isWebVisible.toggle()
                        }
                    } label: {
                        Text(vm.toolbarButtonComputedText)
                            .padding(.horizontal, isPad ? 19 : 5)
                            .foregroundStyle(.white) // simulator 17.x, 18.x 不加入會不顯示圖標文字
                    }
                }
            }
        }
    }
}

// 4 個多元時數 共用 View，ProgressBar + 標題 + 背景 + 數字
struct DiverseHoursRow: View {
    let title: LocalizedStringKey
    let current: String
    let total: String
    let isPad: Bool
    
    var body: some View {
        
        let current1 = Float(current) ?? 0
        let total1   = Float(total) ?? 0
        let progress = CGFloat(total1 > 0 ? current1 / total1 : 0)

        Text(title)
            .font(.system(size: isPad ? 31 : 20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 7)
        DiverseHoursProgressBarShape()
            .stroke(.primary, lineWidth: 1)
            .background(DiverseHoursProgressBarFilled(progress: progress))
            .frame(width: .infinity, height: isPad ? 37 : 20)
            .padding()
            .background(
                ZStack(alignment: .bottom) {
                    Color.gray.opacity(0.2)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("\(current)／\(total)")
                        .font(.system(size: isPad ? 24 : 17))
                        .padding(2)
                        .padding(.leading, isPad ? 267 : 129)
                }
            )
    }
}
