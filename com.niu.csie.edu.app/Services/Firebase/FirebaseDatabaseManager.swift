import Foundation
import FirebaseDatabase



final class FirebaseDatabaseManager {
    
    static let shared = FirebaseDatabaseManager()
    private let ref = Database.database().reference()
    private let achievement = AchievementsMethod()

    func ensureUserNodeExists(for studentId: String, name: String) {
        let userRef = ref.child("users").child(studentId)
        userRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("使用者節點已存在：users/\(studentId)")
                // 讀取首次登入日期
                if let achievements = snapshot.childSnapshot(forPath: "Achievements").value as? [String: Any],
                    let firstLoginDate = achievements["首次登入日期"] as? String {
                    print("首次登入日期：\(firstLoginDate)")
                    // 檢查相伴 100, 365 天
                    self.achievement.checkAnniversaryAchievements(dateAttempt: firstLoginDate)
                    // 順帶檢查是否同時完成其他成就如 日期成就, 3:00 a.m.
                    self.achievement.checkTimeBasedAchievements()
                }
            } else {
                print("建立新使用者節點：users/\(studentId)")
                self.createNewUserNode(for: studentId, name: name)
            }
        }
    }

    // MARK: - 建立新節點
    private func createNewUserNode(for studentId: String, name: String) {
        TimeService.shared.fetchTaipeiDate { dateString in
            guard let dateString = dateString else {
                print("⚠️ 取得台北時間失敗，改用本機時間")
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
                let fallback = formatter.string(from: Date())
                self.createNode(for: studentId, name: name, date: fallback)
                return
            }
            self.createNode(for: studentId, name: name, date: dateString)
        }
    }

    // MARK: - 寫入 Firebase
    private func createNode(for studentId: String, name: String, date: String) {
        let defaultData: [String: Any] = [
            "Name": processName(name),
            "First_Login_IOS": true,
            "Achievements": [
                "01": true,
                "02": false,
                "03": false,
                "04": false,
                "05": false,
                "06": false,
                "07": false,
                "08": false,
                "09": false,
                "10": false,
                "11": "00000000000000",
                "首次登入日期": date
            ]
        ]

        ref.child("users").child(studentId).setValue(defaultData) { error, _ in
            if let error = error {
                print("建立使用者節點失敗：\(error)")
            } else {
                print("使用者節點建立成功：users/\(studentId)")
                self.achievement.sendNotification(title: NSLocalizedString("Achievements_Get", comment: ""), body: NSLocalizedString("Achievements_01_Title", comment: ""))
                // 順帶檢查是否同時完成其他成就如 日期成就, 3:00 a.m.
                self.achievement.checkTimeBasedAchievements()
            }
        }
    }
    
    // MARK: - 通用讀取資料方法
    func readData(from path: String, completion: @escaping (Any?) -> Void) {
        // 以「/」分割節點，支援像 "app/ver" 這種格式
        let nodes = path.split(separator: "/").map { String($0) }
        var currentRef = ref

        for node in nodes {
            currentRef = currentRef.child(node)
        }

        currentRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                completion(snapshot.value)
            } else {
                print("⚠️ 找不到節點：\(path)")
                completion(nil)
            }
        }
    }
    
    // MARK: - 通用寫入資料方法
    func writeData(to path: String, value: Any, completion: ((Error?) -> Void)? = nil) {
        // 以「/」分割節點
        let nodes = path.split(separator: "/").map { String($0) }
        var currentRef = ref

        for node in nodes {
            currentRef = currentRef.child(node)
        }

        currentRef.setValue(value) { error, _ in
            if let error = error {
                print("寫入失敗：\(error.localizedDescription)")
                completion?(error)
            } else {
                completion?(nil)
            }
        }
    }
    
    // MARK: - 通用刪除資料方法
    func deleteData(at path: String, completion: ((Error?) -> Void)? = nil) {
        // 以「/」分割節點
        let nodes = path.split(separator: "/").map { String($0) }
        var currentRef = ref

        for node in nodes {
            currentRef = currentRef.child(node)
        }

        currentRef.removeValue { error, _ in
            if let error = error {
                print("刪除失敗：\(error.localizedDescription)")
                completion?(error)
            } else {
                completion?(nil)
            }
        }
    }
    
    // 處理姓名
    private func processName(_ name: String) -> String {
        let length = name.count

        if length == 2 {
            let first = name.first!
            return "\(first)○"
        } else if length > 2 {
            let first = name.first!
            let last = name.last!
            let middle = String(repeating: "○", count: length - 2)
            return "\(first)\(middle)\(last)"
        } else {
            // 只有一個字就原樣返回
            return name
        }
    }

}
