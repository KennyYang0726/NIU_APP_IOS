import SwiftUI



@MainActor
final class ScoreInquiry_Tab_ListViewModel: ObservableObject, Identifiable {
    
    let name: String
    let score: String
    let elective: String
    
    init(name: String, score: String, elective: String) {
        self.name = name
        self.score = score
        self.elective = elective
    }
    
    var localizedScoreText: LocalizedStringKey {
        switch score {
        case "未上傳": return "Not_uploaded"
        default: return LocalizedStringKey(score)
        }
    }
    
    var localizedElectiveText: LocalizedStringKey {
        switch elective {
        case "選修": return "Elective"
        case "必修": return "Obligatory"
        default: return LocalizedStringKey(elective)
        }
    }
    
    // 分數顏色 parse float < 60 -> 紅色
    var scoreColor: Color {
        // 1. 未上傳
        if score == "未上傳" {
            return .secondary
        }
        // 2. 可解析數字
        if let value = Float(score) {
            if value < 60 {
                return .red       // 不及格 → 紅色
            }
        }
        // 3. 其他無法解析的字串
        return .secondary
    }
    
    // 排序
    var sortKey: Float {
        if score == "未上傳" {
            return .infinity        // 未上傳最高
        }
        if let value = Float(score) {
            return value            // 分數高 → 排前
        }
        return -.infinity           // 無法解析 → 排最後
    }

}
