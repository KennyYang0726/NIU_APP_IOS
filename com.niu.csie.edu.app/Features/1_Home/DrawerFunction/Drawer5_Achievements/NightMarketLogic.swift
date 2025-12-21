import Foundation
import CoreLocation


// 景點資料結構
struct Spot {
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double
}

struct MatchedSpot {
    let index: Int
    let name: String
    let isMatched: Bool
}

final class NightMarketLogic {

    // 景點資料
    static let spots: [Spot] = [
        Spot(name: "東門夜市", latitude: 24.758140, longitude: 121.758050, radius: 160),
        Spot(name: "羅東夜市", latitude: 24.676150, longitude: 121.769659, radius: 250),
        Spot(name: "員山夜市", latitude: 24.745119, longitude: 121.724427, radius: 190),
        Spot(name: "冬山夜市", latitude: 24.634899, longitude: 121.792794, radius: 200),
        Spot(name: "礁溪溫泉夜市", latitude: 24.825148, longitude: 121.760581, radius: 320),
        Spot(name: "壯圍番社同安廟口夜市", latitude: 24.733745, longitude: 121.817740, radius: 150),
        Spot(name: "三星夜市", latitude: 24.669425, longitude: 121.653343, radius: 100),
        Spot(name: "頭城夜市", latitude: 24.855386, longitude: 121.821405, radius: 230),
        Spot(name: "清溝夜市", latitude: 24.661063, longitude: 121.760875, radius: 600),
        Spot(name: "蘇澳頂寮夜市", latitude: 24.644374, longitude: 121.832876, radius: 100),
        Spot(name: "蘇澳夜市", latitude: 24.593593, longitude: 121.841677, radius: 230),
        Spot(name: "馬賽夜市", latitude: 24.617340, longitude: 121.838315, radius: 100),
        Spot(name: "南方澳夜市", latitude: 24.584273, longitude: 121.865151, radius: 100),
        Spot(name: "南澳夜市", latitude: 24.463239, longitude: 121.802785, radius: 100),
    ]

    // 固定時間區段：17:30:00 ~ 22:30:00
    static func isInTimeRange(timeNow: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_TW")

        let now = formatter.date(from: timeNow)!
        let start = formatter.date(from: "17:30:00")!
        let end = formatter.date(from: "22:30:00")!

        return now >= start && now <= end
    }

    // 星期判斷：星期日 = 0
    static func checkDayOfWeek(index: Int, day: String) -> Bool {
        switch index {
        case 0: return true         // 東門
        case 1: return true         // 羅東
        case 2: return day == "4"   // 員山
        case 3: return day == "6"   // 冬山
        case 4: return day == "0"   // 礁溪
        case 5: return day == "6"   // 壯圍
        case 6: return day == "5"   // 三星
        case 7: return day == "5"   // 頭城
        case 8: return day == "3"   // 清溝
        case 9: return day == "4"   // 頂寮路
        case 10: return day == "0"  // 蘇澳
        case 11: return day == "6"  // 馬賽
        case 12: return day == "1"  // 南方澳
        case 13: return day == "2"  // 南澳
        default:
            return false
        }
    }

    // 距離判斷 (Haversine)
    static func distanceInMeters(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {

        let earthRadius = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180)
            * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    // 主邏輯：永不回傳 nil
    static func getMatchedSpot(
        latitude: Double,
        longitude: Double,
        timeNow: String,
        dayOfWeek: String
    ) -> MatchedSpot {

        // 時間不符合 → 直接回傳不符合
        if !isInTimeRange(timeNow: timeNow) {
            return MatchedSpot(index: -1, name: "", isMatched: false)
        }

        // 檢查所有景點
        for (index, spot) in spots.enumerated() {

            // 距離判斷
            let dist = distanceInMeters(
                lat1: latitude,
                lon1: longitude,
                lat2: spot.latitude,
                lon2: spot.longitude
            )
            if dist > spot.radius {
                continue
            }

            // 星期判斷
            if !checkDayOfWeek(index: index, day: dayOfWeek) {
                continue
            }

            // 全部條件成立 → 回傳成功
            return MatchedSpot(
                index: index,
                name: spot.name,
                isMatched: true
            )
        }

        // 無符合 → 回傳安全資料
        return MatchedSpot(index: -1, name: "", isMatched: false)
    }
}
