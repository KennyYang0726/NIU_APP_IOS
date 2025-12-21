import SwiftUI



struct ScoreInquiry_Tab_ListView: View {
    
    @ObservedObject var vm: ScoreInquiry_Tab_ListViewModel
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        VStack(alignment: .leading, spacing: isPad ? 5 : 2) {
            Text(vm.name)
                .font(.system(size: isPad ? 41 : 23))
                .foregroundColor(.primary)
                .padding(.horizontal, isPad ? 23 : 11)
                .padding(.top, isPad ? 15 : 13)
            HStack {
                HStack {
                    Text("score")
                    Text(vm.localizedScoreText)
                        .foregroundColor(vm.scoreColor)
                }
                .font(.system(size: isPad ? 33 : 19))
                .foregroundColor(.secondary)
                Spacer()
                Text(vm.localizedElectiveText)
                    .font(.system(size: isPad ? 33 : 19))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, isPad ? 23 : 11)
            .padding(.vertical, isPad ? 15 : 9)
        }
        .background(Color("Linear_Inside"))
        .cornerRadius(19)
        .background(RoundedRectangle(cornerRadius: 19).stroke(.black, lineWidth: 1))
        .shadow(radius: 2)
        .padding(.horizontal, isPad ? 29 : 11)
    }
}
