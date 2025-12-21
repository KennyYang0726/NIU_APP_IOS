import Foundation



final class LoginRepository {
    private let loginPrefs = UserDefaults(suiteName: "LoginPrefs")!

    private let keyUsername = "username"
    private let keyPassword = "password"

    func saveCredentials(username: String, password: String) {
        loginPrefs.set(username, forKey: keyUsername)
        loginPrefs.set(password, forKey: keyPassword)
    }

    func loadCredentials() -> (username: String, password: String)? {
        guard let username = loginPrefs.string(forKey: keyUsername),
              let password = loginPrefs.string(forKey: keyPassword),
              !username.isEmpty, !password.isEmpty else {
            return nil
        }
        return (username, password)
    }

    func clearCredentials() {
        loginPrefs.set("", forKey: keyUsername)
        loginPrefs.set("", forKey: keyPassword)
    }
}
