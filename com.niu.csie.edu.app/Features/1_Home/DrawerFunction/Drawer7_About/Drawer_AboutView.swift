import SwiftUI

struct Drawer_AboutView: View {
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        ScrollView {
            VStack(spacing: isPad ? 49 : 30) {
                
                // === Developer 區塊 ===
                VStack(spacing: isPad ? 24 : 16) {
                    Text(LocalizedStringKey("Developer"))
                        .font(.system(size: isPad ? 90 : 41, weight: .bold))
                        .foregroundColor(Color("Text_Color"))
                        .multilineTextAlignment(.center)
                        .underline()
                    
                    Image("james")
                        .resizable()
                        .frame(width: isPad ? 310 : 120, height: isPad ? 310 : 120)

                    Text("楊博凱")
                        .font(.system(size: isPad ? 71 : 29))
                        .foregroundColor(.primary)

                    Text(LocalizedStringKey("Developer_0"))
                        .font(.system(size: isPad ? 80 : 31, weight: .bold))
                        .foregroundColor(.primary)
                        .underline()

                    HStack(spacing: isPad ? 37 : 36) {
                        memberView(image: "peter", name: "章沛倫", role: "Information_Engineering")
                        memberView(image: "shao", name: "呂紹誠", role: "Information_Engineering")
                    }

                    HStack(spacing: isPad ? 37 : 36) {
                        memberView(image: "ken", name: "周楷崴", role: "Information_Engineering")
                        memberView(image: "david", name: "賴宥蓁", role: "Information_Engineering")
                    }
                }
                .padding(isPad ? 20 : 20) // 內部間距一致
                .frame(maxWidth: .infinity) // 區塊撐滿
                .background(
                    RoundedRectangle(cornerRadius: 23)
                        .foregroundColor(Color("Linear_Inside"))
                )
                
                
                // === Instructor 區塊 ===
                VStack(spacing: isPad ? 24 : 16) {
                    Text(LocalizedStringKey("Instructor"))
                        .font(.system(size: isPad ? 90 : 41, weight: .bold))
                        .foregroundColor(Color("Text_Color"))
                        .multilineTextAlignment(.center)
                        .underline()
                    
                    Image("chhuang")
                        .resizable()
                        .frame(width: isPad ? 390 : 190, height: isPad ? 390 : 190)
                    
                    Text(LocalizedStringKey("DR_ChaoHsi"))
                        .font(.system(size: isPad ? 67 : 23))
                        .foregroundColor(.primary)
                    
                    Text(LocalizedStringKey("Information_Engineering_DR"))
                        .font(.system(size: isPad ? 51 : 19))
                        .foregroundColor(.secondary)
                }
                .padding(isPad ? 20 : 20) // 內部間距一致
                .frame(maxWidth: .infinity) // 區塊撐滿
                .background(
                    RoundedRectangle(cornerRadius: 23)
                        .foregroundColor(Color("Linear_Inside"))
                )
                
            }
            .padding(.vertical, isPad ? 32 : 20)
            .padding(.horizontal, isPad ? 32 : 20) // 統一控制左右 margin
        }
        .background(Color("Linear").ignoresSafeArea()) // 全域底色
    }
    
    // 小組成員元件
    private func memberView(image: String, name: String, role: LocalizedStringKey) -> some View {
        VStack(spacing: isPad ? 12 : 8) {
            Image(image)
                .resizable()
                .frame(width: isPad ? 270 : 110, height: isPad ? 270 : 110)
            
            Text(name)
                .font(.system(size: isPad ? 66 : 23))
                .foregroundColor(.primary)
            
            Text(role)
                .font(.system(size: isPad ? 51 : 19))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
