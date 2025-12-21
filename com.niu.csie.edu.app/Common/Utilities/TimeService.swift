import Foundation

// completion 是這在任務完成後回傳結果，和return不同是，用於非同步工作結束之後，把結果傳回呼叫者

final class TimeService {
    static let shared = TimeService()
    private init() {}

    // MARK: - 取得「完整台北時間字串」
    func fetchTaipeiDateTime(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://www.stdtime.gov.tw/Home/GetServerTime") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("🌐 無法取得時間：\(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data,
                  var responseString = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }

            responseString = responseString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            completion(responseString) // e.g. 2025-10-13T22:36:07.7951081+08:00
        }.resume()
    }

    // MARK: - 取得「台北日期」yyyy-MM-dd
    func fetchTaipeiDate(completion: @escaping (String?) -> Void) {
        fetchTaipeiDateTime { datetime in
            guard let datetime = datetime else {
                completion(nil)
                return
            }
            let datePart = datetime.split(separator: "T").first ?? ""
            completion(String(datePart))
        }
    }

    // MARK: - 取得「星期幾」
    func fetchTaipeiWeekdayNumber(completion: @escaping (String?) -> Void) {
        fetchTaipeiDateTime { datetime in
            guard var datetime = datetime else {
                completion(nil)
                return
            }
            
            // 修正格式："2025-10-13T22:36:07.7951081+08:00" → "2025-10-13T22:36:07+08:00"
            if let dotRange = datetime.range(of: ".") {
                let timeZonePart = datetime.split(separator: "+").last ?? ""
                datetime = datetime[..<dotRange.lowerBound] + "+\(timeZonePart)"
            }

            // datetime 範例："2025-10-13T22:36:07.7951081+08:00"
            let formatter = ISO8601DateFormatter()
            // ISO8601DateFormatter 會自動支援 +08:00 時區
            guard let date = formatter.date(from: datetime) else {
                completion(nil)
                return
            }

            // 取得星期幾（1=Sunday, 2=Monday, ... 7=Saturday）
            let calendar = Calendar(identifier: .gregorian)
            let weekday = calendar.component(.weekday, from: date)
            // 轉換成要的格式：Sunday=0, Monday=1, ..., Saturday=6
            // Swift weekday: Sunday=1 → 轉為 0；Monday=2 → 1；... Saturday=7 → 6
            let mapped = (weekday + 6) % 7
            let dayOfWeek = String(mapped)
            completion(dayOfWeek)
        }
    }

    // MARK: - 取得「台北時間」HH:mm:ss
    func fetchTaipeiClock(completion: @escaping (String?) -> Void) {
        fetchTaipeiDateTime { datetime in
            guard let datetime = datetime else {
                completion(nil)
                return
            }

            let parts = datetime.split(separator: "T")
            guard parts.count >= 2 else {
                completion(nil)
                return
            }

            // 取時間部分（移除毫秒與時區）
            let timeRaw = parts[1]
            let timeClean = timeRaw.split(separator: ".").first ?? timeRaw
            completion(String(timeClean.prefix(8))) // e.g. "22:36:07"
        }
    }
}




/*
// 取得星期（數字）
TimeService.shared.fetchTaipeiWeekdayNumber { weekday in
    if let weekday = weekday {
        print("🗓️ 星期（數字）：\(weekday)")  // Sunday=0, Monday=1, ...
    } else {
        print("🗓️ 無法取得星期")
    }
}

// 取得時間
TimeService.shared.fetchTaipeiClock { time in
    print("⏰ 時間：\(time ?? "取得失敗")")
}
*/
