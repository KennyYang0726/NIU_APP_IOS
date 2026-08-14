import Foundation



struct FAQItem: Identifiable {
    let id: String
    let questionKey: String
    let answerKey: String
}


/// Drawer 常見問答資料。
/// 新增常見問答時，只需：
/// 1. 在 Localizable.strings 加入問題與答案字串。
/// 2. 在 defaultItems 加入一筆 FAQItem。
enum Drawer_FAQsModel {
    static let defaultItems: [FAQItem] = [
        FAQItem(
            id: "01",
            questionKey: "FAQ_Question_01",
            answerKey: "FAQ_Answer_01"
        ),
        FAQItem(
            id: "02",
            questionKey: "FAQ_Question_02",
            answerKey: "FAQ_Answer_02"
        ),
        FAQItem(
            id: "03",
            questionKey: "FAQ_Question_03",
            answerKey: "FAQ_Answer_03"
        )
    ]
}
