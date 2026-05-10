import Foundation
import Combine



final class SSOSession: ObservableObject {
    static let shared = SSOSession()

    private let suite = UserDefaults(suiteName: "SSOSession")!

    @Published var token: String {
        didSet { suite.set(token, forKey: Keys.token) }
    }

    @Published var tokenExp: String {
        didSet { suite.set(tokenExp, forKey: Keys.tokenExp) }
    }

    @Published var guid1: String {
        didSet { suite.set(guid1, forKey: Keys.guid1) }
    }

    @Published var guid2: String {
        didSet { suite.set(guid2, forKey: Keys.guid2) }
    }

    @Published var guid3: String {
        didSet { suite.set(guid3, forKey: Keys.guid3) }
    }

    private enum Keys {
        static let token = "token"
        static let tokenExp = "tokenExp"
        static let guid1 = "guid1"
        static let guid2 = "guid2"
        static let guid3 = "guid3"
    }

    private init() {
        self.token = suite.string(forKey: Keys.token) ?? ""
        self.tokenExp = suite.string(forKey: Keys.tokenExp) ?? ""
        self.guid1 = suite.string(forKey: Keys.guid1) ?? ""
        self.guid2 = suite.string(forKey: Keys.guid2) ?? ""
        self.guid3 = suite.string(forKey: Keys.guid3) ?? ""
    }

    func update(token: String, exp: String?) {
        self.token = token
        self.tokenExp = exp ?? ""
    }

    func updateGUIDs(
        guid1: String,
        guid2: String,
        guid3: String
    ) {
        self.guid1 = guid1
        self.guid2 = guid2
        self.guid3 = guid3
    }

    func updateGUID1(_ guid: String) {
        self.guid1 = guid
    }

    func updateGUID2(_ guid: String) {
        self.guid2 = guid
    }

    func updateGUID3(_ guid: String) {
        self.guid3 = guid
    }

    func clear() {
        token = ""
        tokenExp = ""
        guid1 = ""
        guid2 = ""
        guid3 = ""

        suite.removeObject(forKey: Keys.token)
        suite.removeObject(forKey: Keys.tokenExp)
        suite.removeObject(forKey: Keys.guid1)
        suite.removeObject(forKey: Keys.guid2)
        suite.removeObject(forKey: Keys.guid3)
    }

    var hasToken: Bool {
        !token.isEmpty
    }

    var hasGUID1: Bool {
        !guid1.isEmpty
    }

    var hasGUID2: Bool {
        !guid2.isEmpty
    }

    var hasGUID3: Bool {
        !guid3.isEmpty
    }
}
