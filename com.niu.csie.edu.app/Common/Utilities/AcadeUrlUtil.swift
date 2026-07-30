import Foundation



final class AcadeUrlUtil {

    private static let baseUrl = "https://acade.niu.edu.tw/NIU/outside.aspx?mainPage="
    typealias Param = (key: String, value: String)
    private init() {}
    static func param(_ key: String, _ value: String) -> Param {
        return (key: key, value: value)
    }

    /// 建立標準功能入口網址。
    ///
    /// 例：
    /// GRD5131
    /// → Application/GRD/GRD51/GRD5131_.aspx?Progcd=GRD5131
    static func buildUrl(code: String, guid: String) throws -> String {
        let fullCode = try normalizeCode(code)

        return try buildPageUrl(
            code: fullCode,
            pageSuffix: "_",
            guid: guid,
            params: [
                param("Progcd", fullCode)
            ]
        )
    }

    /// 建立標準功能入口網址，並額外帶參數。
    ///
    /// 參數順序：
    /// Progcd會固定放第一個，extraParams依照輸入順序接在後面。
    static func buildUrl(
        code: String,
        guid: String,
        extraParams: [Param]
    ) throws -> String {
        let fullCode = try normalizeCode(code)

        var params: [Param] = [
            param("Progcd", fullCode)
        ]
        params.append(contentsOf: extraParams)

        return try buildPageUrl(
            code: fullCode,
            pageSuffix: "_",
            guid: guid,
            params: params
        )
    }

    /// 建立指定頁面後綴的outside.aspx網址。
    ///
    /// pageSuffix可傳：
    /// "_"   → ENRG010_.aspx
    /// "_01" → ENRG010_01.aspx
    /// "01"  → ENRG010_01.aspx
    ///
    /// params會完全按照輸入順序組成query string。
    static func buildPageUrl(
        code: String,
        pageSuffix: String,
        guid: String,
        params: [Param]
    ) throws -> String {
        let target = try buildTarget(
            code: code,
            pageSuffix: pageSuffix,
            params: params
        )

        return try buildOutsideUrlFromTarget(target, guid: guid)
    }

    /// 直接把完整ACADE target轉成outside.aspx網址。
    ///
    /// 例：
    /// Application/ENR/ENRG0/ENRG010_01.aspx?ADD_TYPE=00&OPEN_MARK=Y&STNO=R1443017
    static func buildOutsideUrlFromTarget(
        _ targetUrlDecode: String,
        guid: String
    ) throws -> String {
        guard !targetUrlDecode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AcadeUrlError.emptyTargetUrl
        }

        guard !guid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AcadeUrlError.emptyGuid
        }

        guard let utf16LE = targetUrlDecode.data(using: .utf16LittleEndian) else {
            throw AcadeUrlError.encodingFailed
        }

        let base64 = utf16LE.base64EncodedString()
        let encodedMainPage = percentEncode(base64)
        let encodedGuid = percentEncode(guid)

        return "\(baseUrl)\(encodedMainPage)&GUID=\(encodedGuid)"
    }

    /// 建立尚未UTF-16LE Base64編碼的ACADE目標路徑。
    ///
    /// 例：
    /// code = ENRG010
    /// pageSuffix = _01
    /// params = ADD_TYPE=00, OPEN_MARK=Y, STNO=R1443017
    ///
    /// → Application/ENR/ENRG0/ENRG010_01.aspx?ADD_TYPE=00&OPEN_MARK=Y&STNO=R1443017
    static func buildTarget(
        code: String,
        pageSuffix: String,
        params: [Param]
    ) throws -> String {
        let fullCode = try normalizeCode(code)
        let normalizedPageSuffix = try normalizePageSuffix(pageSuffix)

        let systemFolder = String(fullCode.prefix(3))
        let groupFolder = String(fullCode.prefix(5))

        var target = "Application/\(systemFolder)/\(groupFolder)/\(fullCode)\(normalizedPageSuffix).aspx"

        let query = try buildQuery(params)
        if !query.isEmpty {
            target += "?\(query)"
        }

        return target
    }

    private static func normalizeCode(_ code: String) throws -> String {
        let fullCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard fullCode.count >= 5 else {
            throw AcadeUrlError.invalidCode(code)
        }

        let pattern = #"^[A-Z]{3}[A-Z0-9]*\d+$"#
        guard fullCode.range(of: pattern, options: .regularExpression) != nil else {
            throw AcadeUrlError.invalidCode(code)
        }

        return fullCode
    }

    private static func normalizePageSuffix(_ pageSuffix: String) throws -> String {
        let suffix = pageSuffix.trimmingCharacters(in: .whitespacesAndNewlines)

        if suffix.isEmpty || suffix == "_" {
            return "_"
        }

        if suffix.range(of: #"^\d{2}$"#, options: .regularExpression) != nil {
            return "_\(suffix)"
        }

        if suffix.range(of: #"^_\d{2}$"#, options: .regularExpression) != nil {
            return suffix
        }

        throw AcadeUrlError.invalidPageSuffix(pageSuffix)
    }

    private static func buildQuery(_ params: [Param]) throws -> String {
        if params.isEmpty {
            return ""
        }

        return try params.map { item in
            let cleanKey = item.key.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanKey.isEmpty else {
                throw AcadeUrlError.emptyQueryKey
            }

            return "\(percentEncode(cleanKey))=\(percentEncode(item.value))"
        }
        .joined(separator: "&")
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=/?%")

        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

enum AcadeUrlError: LocalizedError {
    case invalidCode(String)
    case emptyGuid
    case emptyTargetUrl
    case invalidPageSuffix(String)
    case emptyQueryKey
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidCode(let code):
            return "Invalid code: \(code)"
        case .emptyGuid:
            return "GUID is empty"
        case .emptyTargetUrl:
            return "Target URL is empty"
        case .invalidPageSuffix(let pageSuffix):
            return "Invalid pageSuffix: \(pageSuffix)"
        case .emptyQueryKey:
            return "Query key is empty"
        case .encodingFailed:
            return "Encoding failed"
        }
    }
}
