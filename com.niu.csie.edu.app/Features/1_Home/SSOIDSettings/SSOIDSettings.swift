import Foundation



final class SSOIDSettings: ObservableObject {
    static let shared = SSOIDSettings()

    // 專用 suite（你要求的 Suite 名稱）
    private let suite = UserDefaults(suiteName: "SSOID")!

    // 封裝欄位：SSOID
    @Published var EUNI: String {
        didSet { SSOIDSettings.save(EUNI, key: "EUNI", to: suite) }
    }
    @Published var acade_main: String {
        didSet { SSOIDSettings.save(acade_main, key: "acade_main", to: suite) }
    }
    @Published var acade_subject_system: String {
        didSet { SSOIDSettings.save(acade_subject_system, key: "acade_subject_system", to: suite) }
    }
    @Published var ccsys: String {
        didSet { SSOIDSettings.save(ccsys, key: "ccsys", to: suite) }
    }

    private init() {
        self.EUNI = suite.string(forKey: "EUNI") ?? ""
        self.acade_main = suite.string(forKey: "acade_main") ?? ""
        self.acade_subject_system = suite.string(forKey: "acade_subject_system") ?? ""
        self.ccsys = suite.string(forKey: "ccsys") ?? ""
    }
    
    /// 一次更新多個欄位（未提供的參數就不動）
    func bulkUpdate(
        EUNI: String? = nil,
        acade_main: String? = nil,
        acade_subject_system: String? = nil,
        ccsys: String? = nil
    ) {
        if let v = EUNI { self.EUNI = v }
        if let v = acade_main { self.acade_main = v }
        if let v = acade_subject_system { self.acade_subject_system = v }
        if let v = ccsys { self.ccsys = v }
    }

    private static func save<T>(_ value: T, key: String, to prefs: UserDefaults) {
        prefs.set(value, forKey: key)
    }
}
