import SwiftUI



struct Drawer_SponsorView: View {
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        ScrollView {
            VStack(spacing: isPad ? 49 : 30) {
                
                // === 說明區塊 ===
                VStack(spacing: isPad ? 24 : 16) {
                    Text(LocalizedStringKey("Sponsor_Text"))
                        .font(.system(size: isPad ? 41 : 23))
                        .foregroundColor(Color("Text_Color"))
                        .multilineTextAlignment(.leading)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 23)
                        .foregroundColor(Color("Linear_Inside"))
                )
                
                // === 斗內方法區塊 ===
                VStack(spacing: isPad ? 24 : 16) {
                    /*
                    // 銀行轉帳
                    VStack(alignment: .leading, spacing: 8) {
                        Text("銀行轉帳")
                            .font(.system(size: isPad ? 37 : 23, weight: .bold))
                        Text("銀行名稱: XXXX\n帳號: 1234567890")
                            .font(.system(size: isPad ? 29 : 17))
                        
                        Button(action: {
                            // 複製帳號或跳轉
                        }) {
                            Text("複製帳號")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 23)
                            .foregroundColor(Color("Linear_Inside"))
                    )*/
                    // 街口支付
                    HStack(spacing: isPad ? 32 : 17) {
                        Image("JK_Pay_QR") // QR code 圖片
                            .resizable()
                            .scaledToFit()
                            .frame(width: isPad ? 250 : 150, height: isPad ? 250 : 150)
                            .cornerRadius(7)
                        
                        VStack(alignment: .leading, spacing: 11) {
                            Text(LocalizedStringKey("JKPay_Text"))
                                .font(.system(size: isPad ? 31 : 23, weight: .bold))
                            Text(LocalizedStringKey("Scan_QR_Text"))
                                .font(.system(size: isPad ? 29 : 17))
                            
                            Button(action: {
                                guard let url = URL(string: "https://service.jkopay.com/r/transfer?j=Transfer:909029869") else { return }
                                UIApplication.shared.open(url)
                            }) {
                                Text(LocalizedStringKey("Open_JKPay"))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("BG_Color"))
                                    .cornerRadius(19)
                            }
                        }
                    }
                    .padding(17)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 23)
                            .foregroundColor(Color("Linear_Inside"))
                    )
                    // 悠遊付
                    HStack(spacing: isPad ? 32 : 17) {
                        Image("EZWallet_QR") // QR code 圖片
                            .resizable()
                            .scaledToFit()
                            .frame(width: isPad ? 250 : 150, height: isPad ? 250 : 150)
                            .cornerRadius(7)
                        
                        VStack(alignment: .leading, spacing: 11) {
                            Text(LocalizedStringKey("EZWallet_Text"))
                                .font(.system(size: isPad ? 31 : 23, weight: .bold))
                            Text(LocalizedStringKey("Scan_QR_Text"))
                                .font(.system(size: isPad ? 29 : 17))
                            
                            Button(action: {
                                guard let url = URL(string: "https://epkaw.easycard.com.tw/deepLink/receiver/0/2202007271390121") else { return }
                                UIApplication.shared.open(url)
                            }) {
                                Text(LocalizedStringKey("Open_EZWallet"))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("BG_Color"))
                                    .cornerRadius(19)
                            }
                        }
                    }
                    .padding(17)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 23)
                            .foregroundColor(Color("Linear_Inside"))
                    )
                    
                }
            }
            .padding(.vertical, isPad ? 32 : 20)
            .padding(.horizontal, isPad ? 32 : 20)
        }
        .background(Color("Linear").ignoresSafeArea())
    }
}
