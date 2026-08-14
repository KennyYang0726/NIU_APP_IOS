import SwiftUI



enum AppTheme: String, CaseIterable {
    case `default`
    case bright
    case dark
}

// App 內顯示語言。
// default = 跟隨系統；目前支援繁體中文（台灣）、日本語、English。
enum AppLanguage: String, CaseIterable, Identifiable {
    case `default`
    case traditionalChinese
    case japanese
    case english

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .default:
            return "language_default"
        case .traditionalChinese:
            return "language_zh_tw"
        case .japanese:
            return "language_jp"
        case .english:
            return "language_english"
        }
    }

    fileprivate var lprojName: String? {
        switch self {
        case .default:
            return nil
        case .traditionalChinese:
            return "zh-Hant"
        case .japanese:
            return "ja"
        case .english:
            return "en"
        }
    }
}

// 統一處理非 SwiftUI LocalizedStringKey 的字串。
// SwiftUI 畫面由 RootView 的 locale environment 處理；
// AppLocalization.localized 類型的使用點則改由此處依 App 語言設定讀取對應 lproj。
enum AppLocalization {
    private static let languagePrefs = UserDefaults(suiteName: "AppLanguagePrefs")!
    private static let languageKey = "language"

    static var savedLanguage: AppLanguage {
        guard let rawValue = languagePrefs.string(forKey: languageKey),
              let language = AppLanguage(rawValue: rawValue)
        else {
            return .default
        }

        return language
    }

    static func resolvedLanguage(for language: AppLanguage) -> AppLanguage {
        guard language == .default else {
            return language
        }

        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? "en"

        // 只把繁體中文系統語言映射到 zh-Hant；簡體中文沒有對應翻譯時回到 English。
        if preferredLanguage.hasPrefix("zh-hant")
            || preferredLanguage.hasPrefix("zh-tw")
            || preferredLanguage.hasPrefix("zh-hk")
            || preferredLanguage.hasPrefix("zh-mo") {
            return .traditionalChinese
        }

        if preferredLanguage.hasPrefix("ja") {
            return .japanese
        }

        return .english
    }

    static func locale(for language: AppLanguage) -> Locale {
        switch resolvedLanguage(for: language) {
        case .traditionalChinese:
            return Locale(identifier: "zh-Hant-TW")
        case .japanese:
            return Locale(identifier: "ja")
        case .english, .default:
            return Locale(identifier: "en")
        }
    }

    static func localized(
        _ key: String,
        comment: String = ""
    ) -> String {
        let language = resolvedLanguage(for: savedLanguage)
        let bundle = localizationBundle(for: language)

        return bundle.localizedString(
            forKey: key,
            value: nil,
            table: nil
        )
    }

    private static func localizationBundle(for language: AppLanguage) -> Bundle {
        if let lprojName = language.lprojName,
           let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        // 尚未加入某語系檔時，不顯示 key，直接回到 English。
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return .main
    }
}

final class AppSettings: ObservableObject {
    private let infoPrefs = UserDefaults(suiteName: "Infos")!
    private let themePrefs = UserDefaults(suiteName: "AppThemePrefs")!
    private let languagePrefs = UserDefaults(suiteName: "AppLanguagePrefs")!

    @Published var theme: AppTheme {
        didSet { AppSettings.save(theme.rawValue, key: "theme", to: themePrefs) }
    }

    @Published var language: AppLanguage {
        didSet { AppSettings.save(language.rawValue, key: "language", to: languagePrefs) }
    }

    @Published var semester: Int {
        didSet { AppSettings.save(semester, key: "Semester", to: infoPrefs) }
    }

    @Published var name: String {
        didSet { AppSettings.save(name, key: "Name", to: infoPrefs) }
    }

    init() {
        // --- 主題 ---
        if let savedTheme = themePrefs.string(forKey: "theme"),
           let loadedTheme = AppTheme(rawValue: savedTheme) {
            self.theme = loadedTheme
        } else {
            self.theme = .default
            AppSettings.save(AppTheme.default.rawValue, key: "theme", to: themePrefs)
        }

        // --- 語言 ---
        // 舊版沒有 language key 時，一律使用 default（跟隨系統）。
        if let savedLanguage = languagePrefs.string(forKey: "language"),
           let loadedLanguage = AppLanguage(rawValue: savedLanguage) {
            self.language = loadedLanguage
        } else {
            self.language = .default
            AppSettings.save(AppLanguage.default.rawValue, key: "language", to: languagePrefs)
        }

        // --- 學年度 ---
        if infoPrefs.object(forKey: "Semester") == nil {
            self.semester = 114
            AppSettings.save(114, key: "Semester", to: infoPrefs)
        } else {
            self.semester = infoPrefs.integer(forKey: "Semester")
        }

        // --- 名字 ---
        if let storedName = infoPrefs.string(forKey: "Name") {
            self.name = storedName
        } else {
            self.name = "窩不知道"
            AppSettings.save(self.name, key: "Name", to: infoPrefs)
        }
    }

    // 改為 static function，不依賴 self
    private static func save<T>(_ value: T, key: String, to prefs: UserDefaults) {
        prefs.set(value, forKey: key)
    }
}
