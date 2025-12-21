import Foundation

// completion 是這在任務完成後回傳結果，和return不同是，用於非同步工作結束之後，把結果傳回呼叫者
/*
final class TimeService {
    static let shared = TimeService()
    private init() {}

    // MARK: - 取得「完整台北時間字串」
    func fetchTaipeiDateTime(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://timeapi.io/api/time/current/zone?timeZone=Asia/Taipei") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 7.0

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
            
            let parts = datetime.split(separator: "\"dateTime\":\"")
            guard parts.count >= 2 else {
                completion(nil)
                return
            }
            
            // 取星期部分（移除後半部資訊）
            let datePartRaw = parts[1]
            let datePart = datePartRaw.split(separator: "T").first ?? ""
            completion(String(datePart))
        }
    }

    // MARK: - 取得「星期幾」
    func fetchTaipeiWeekdayNumber(completion: @escaping (String?) -> Void) {
        fetchTaipeiDateTime { datetime in
            guard let datetime = datetime else {
                completion(nil)
                return
            }
            
            let parts = datetime.split(separator: "\"dayOfWeek\":\"")
            guard parts.count >= 2 else {
                completion(nil)
                return
            }

            // 取星期部分（移除後半部資訊）
            let dayOfWeekRaw = parts[1]
            let dayOfWeek = dayOfWeekRaw.split(separator: "\"").first ?? dayOfWeekRaw
            completion(String(dayOfWeek))
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
*/
