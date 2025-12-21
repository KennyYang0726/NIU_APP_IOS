import SwiftUI



struct EUNI1_ListView: View {
    
    @EnvironmentObject var appState: AppState // 注入狀態
    @ObservedObject var vm: EUNI1_ListViewModel
    
    let parentViewModel: EUNI1ViewModel
    let index: Int   // 這個課程在 courseList 裡的 index
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 課程標題
            HStack {
                Text(vm.name)
                    .font(.system(size: isPad ? 43 : 20))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 19)
                    .foregroundColor(Color("Text_Color"))
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { vm.toggleExpanded() }
            
            if vm.isExpanded {
                VStack(spacing: 6) {
                    // 按順序為 公告 成績 資源 作業 進入課程
                    ForEach(["EUNI_Sub_Item1", "EUNI_Sub_Item2", "EUNI_Sub_Item3", "EUNI_Sub_Item4", "EUNI_Sub_Item5"], id: \.self) { title in
                        Button(action: {
                            // print("\(title) tapped for \(vm.name)")
                            parentViewModel.handleSubItemTap(course: vm, subItem: title, index: index)
                        }) {
                            Text(LocalizedStringKey(title))
                                .font(.system(size: isPad ? 37 : 19, weight: .medium))
                                .foregroundColor(Color("Text_Color"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color("Linear"))
                                .clipShape(RoundedRectangle(cornerRadius: 19))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 19)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color("Linear_Inside"))
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .overlay(
            RoundedRectangle(cornerRadius: 23)
                .stroke(Color.black, lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)

    }

}


/*
#Preview {
    // 用閉包「先組好課程陣列」再拿去 ForEach，避免在 ViewBuilder 內寫 for/var 陳述式
    let courseList: [EUNI1_ListViewModel] = {
        let d = UserDefaults(suiteName: "EUNIcourseData")!
        var out: [EUNI1_ListViewModel] = []
        var i = 0
        while
            let name = d.string(forKey: "課程_\(i)_名稱"),
            let id   = d.string(forKey: "課程_\(i)_ID")
        {
            out.append(EUNI1_ListViewModel(name: name, id: id))
            i += 1
        }
        // 若還沒寫入任何資料，就放幾筆示意資料方便調 UI
        if out.isEmpty {
            out = [
                EUNI1_ListViewModel(name: "1141_行動應用程式(C1IL030004A)", id: "15740"),
                EUNI1_ListViewModel(name: "1141_工程數學(B4CS020003A)", id: "15745"),
                EUNI1_ListViewModel(name: "1141_普通物理(B4CS000005A)", id: "15743"),
            ]
        }
        return out
    }()

    ScrollView {
        VStack(spacing: 8) {
            ForEach(courseList) { vm in
                EUNI1_ListView(vm: vm)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 8)
    }
    .background(Color("Linear"))
}*/
