import Foundation
import FirebaseAuth



final class FirebaseAuthManager {

    static let shared = FirebaseAuthManager()
    private init() {}

    /// 只負責匿名登入，不寫入 Database
    func signInAnonymously() {
        // 如果已經登入過，就不重複登入
        if let currentUser = Auth.auth().currentUser {
            print("已登入匿名帳號：\(currentUser.uid)")
            return
        }

        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                print("匿名登入失敗：\(error.localizedDescription)")
                return
            }

            guard let user = result?.user else {
                print("匿名登入失敗：未取得使用者")
                return
            }

            print("匿名登入成功，UID：\(user.uid)")
        }
    }
}
