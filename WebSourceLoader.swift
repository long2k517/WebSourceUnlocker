import Foundation

@MainActor
final class WebSourceLoader: ObservableObject {
    @Published var rawSource = ""
    @Published var tagNames: [String] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var bypassLog: [String] = []

    private let session: URLSession

    // Regex biên dịch một lần, dùng lại toàn cục
    private static let eventAttrRegexes: [NSRegularExpression] = compile([
        #"oncontextmenu\s*=\s*["'][^"']*["']"#,
        #"oncopy\s*=\s*["'][^"']*["']"#,
        #"onpaste\s*=\s*["'][^"']*["']"#,
        #"oncut\s*=\s*["'][^"']*["']"#,
        #"onselectstart\s*=\s*["'][^"']*["']"#,
        #"ondragstart\s*=\s*["'][^"']*["']"#,
        #"onkeydown\s*=\s*["'][^"']*["']"#
    ], options: [.caseInsensitive])

    private static let scriptBlockRegexes: [NSRegularExpression] = compile([
        #"<script[^>]*>[^<]*?devtools[^<]*?</script>"#,
        #"<script[^>]*>[^<]*?console\.clear[^<]*?</script>"#,
        #"<script[^>]*>[^<]*?contextmenu[^<]*?</script>"#,
        #"<script[^>]*>[^<]*?keycode\s*==\s*123[^<]*?</script>"#,
        #"<script[^>]*>[^<]*?framebusting[^<]*?</script>"#
    ], options: [.caseInsensitive, .dotMatchesLineSeparators])

    private static let unicodeRegex = try! NSRegularExpression(pattern: #"\\u([0-9a-fA-F]{4})"#)
    private static let base64Regex = try! NSRegularExpression(pattern: #"atob\(\s*["']([A-Za-z0-9+/=]{16,})["']\s*\)"#)
    private static let frameBusterRegexes: [NSRegularExpression] = compile([
        #"if\s*\(\s*self\s*==\s*top\s*\)[^;]*;"#,
        #"if\s*\(\s*top\s*!=\s*self\s*\)[^;]*;"#,
        #"if\s*\(\s*window\.top\s*!==\s*window\.self\s*\)[^;]*;"#,
        #"top\.location\s*=\s*self\.location[^;]*;"#
    ], options: [.caseInsensitive])

    private static let tagRegex = try! NSRegularExpression(pattern: #"<\s*([a-zA-Z][a-zA-Z0-9:_-]*)\b"#)

    private static let protectionSignatures: [String] = [
        "contextmenu", "oncontextmenu", "preventdefault", "keydown",
        "keycode==123", "keycode == 123", "f12", "devtools", "debugger",
        "console.clear", "document.onkeydown", "event.button==2",
        "event.button == 2", "selectstart", "user-select", "disable-devtool",
        "devtools-detector", "rightclick", "oncopy", "onpaste", "oncut",
        "view-source", "sourceprotect", "self==top", "top!=self",
        "framebusting", "atob(", "eval(atob", "fromcharcode"
    ]

    private static let entityMap: [(String, String)] = [
        ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&"), ("&quot;", "\""),
        ("&#39;", "'"), ("&#x2F;", "/"), ("&#x3D;", "="),
        ("&#58;", ":"), ("&nbsp;", " ")
    ]

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "vi-VN,vi;q=0.9,en;q=0.8",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache"
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session = URLSession(configuration: config)
    }

    func load(urlString: String) async {
        guard let url = Self.normalize(urlString) else {
            applyError("URL không hợp lệ")
            return
        }

        isLoading = true
        errorMessage = ""
        rawSource = ""
        tagNames = []
        bypassLog = []

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (data, response) = try await session.data(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                errorMessage = "HTTP \(http.statusCode)"
            }

            let text = Self.decode(data: data, charset: Self.charset(from: response))

            var log: [String] = []
            var final = text

            if Self.isProtected(text) {
                log.append("PHÁT HIỆN BẢO VỆ MÃ NGUỒN")
                log.append("TIẾN HÀNH BẺ KHÓA")

                final = Self.stripEventAttrs(final, log: &log)
                final = Self.stripScriptBlocks(final, log: &log)
                final = Self.decodeEntities(final, log: &log)
                final = Self.decodeUnicode(final, log: &log)
                final = Self.decodeBase64(final, log: &log)
                final = Self.stripFrameBusters(final, log: &log)

                log.append("BẺ KHÓA HOÀN TẤT")
            } else {
                log.append("KHÔNG PHÁT HIỆN BẢO VỆ MÃ NGUỒN")
            }

            rawSource = final
            tagNames = Self.extractTags(final)
            bypassLog = log
            isLoading = false
        } catch {
            applyError("Lỗi tải: \(error.localizedDescription)")
        }
    }

    private func applyError(_ message: String) {
        errorMessage = message
        rawSource = ""
        tagNames = []
        isLoading = false
    }

    // MARK: - Helpers

    private static func compile(_ patterns: [String], options: NSRegularExpression.Options) -> [NSRegularExpression] {
        patterns.compactMap { try? NSRegularExpression(pattern: $0, options: options) }
    }

    private static func normalize(_ string: String) -> URL? {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") { value = "https://" + value }
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }

    private static func charset(from response: URLResponse) -> String? {
        guard let http = response as? HTTPURLResponse,
              let ct = http.value(forHTTPHeaderField: "Content-Type") else { return nil }
        let lower = ct.lowercased()
        guard let r = lower.range(of: "charset=") else { return nil }
        return String(lower[r.upperBound...].split(separator: ";").first ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
    }

    private static func decode(data: Data, charset: String?) -> String {
        let v = charset?.lowercased() ?? ""
        let primary: String.Encoding
        if v.contains("utf-8") || v.contains("utf8") { primary = .utf8 }
        else if v.contains("iso-8859-1") || v.contains("latin1") { primary = .isoLatin1 }
        else if v.contains("windows-1252") || v.contains("cp1252") { primary = .windowsCP1252 }
        else if v.contains("utf-16le") { primary = .utf16LittleEndian }
        else if v.contains("utf-16be") { primary = .utf16BigEndian }
        else if v.contains("utf-16") || v.contains("utf16") { primary = .utf16 }
        else { primary = .utf8 }

        if let s = String(data: data, encoding: primary) { return s }
        for enc in [String.Encoding.utf8, .isoLatin1, .windowsCP1252, .utf16, .utf16LittleEndian, .utf16BigEndian] {
            if let s = String(data: data, encoding: enc) { return s }
        }
        return ""
    }

    private static func isProtected(_ source: String) -> Bool {
        let lower = source.lowercased()
        for sig in protectionSignatures where lower.contains(sig) { return true }
        return false
    }

    private static func stripEventAttrs(_ source: String, log: inout [String]) -> String {
        var output = source
        for regex in eventAttrRegexes {
            let range = NSRange(output.startIndex..., in: output)
            let next = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "")
            if next != output { output = next; log.append("ĐÃ XÓA THUỘC TÍNH CHẶN SỰ KIỆN") }
        }
        return output
    }

    private static func stripScriptBlocks(_ source: String, log: inout [String]) -> String {
        var output = source
        for regex in scriptBlockRegexes {
            let range = NSRange(output.startIndex..., in: output)
            let next = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "")
            if next != output { output = next; log.append("ĐÃ XÓA KHỐI SCRIPT BẢO VỆ") }
        }
        return output
    }

    private static func decodeEntities(_ source: String, log: inout [String]) -> String {
        var output = source
        var changed = false
        for (k, v) in entityMap where output.contains(k) {
            output = output.replacingOccurrences(of: k, with: v)
            changed = true
        }
        if changed { log.append("ĐÃ GIẢI MÃ HTML ENTITIES") }
        return output
    }

    private static func decodeUnicode(_ source: String, log: inout [String]) -> String {
        guard source.contains("\\u") else { return source }
        let ns = source as NSString
        let matches = unicodeRegex.matches(in: source, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return source }
        var output = source
        for m in matches.reversed() {
            guard m.numberOfRanges > 1,
                  let code = UInt32(ns.substring(with: m.range(at: 1)), radix: 16),
                  let scalar = Unicode.Scalar(code) else { continue }
            output = output.replacingOccurrences(of: ns.substring(with: m.range), with: String(Character(scalar)))
        }
        log.append("ĐÃ GIẢI MÃ UNICODE ESCAPE")
        return output
    }

    private static func decodeBase64(_ source: String, log: inout [String]) -> String {
        let ns = source as NSString
        let matches = base64Regex.matches(in: source, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return source }
        var output = source
        for m in matches.reversed() {
            guard m.numberOfRanges > 1,
                  let data = Data(base64Encoded: ns.substring(with: m.range(at: 1))),
                  let decoded = String(data: data, encoding: .utf8) else { continue }
            output = output.replacingOccurrences(of: ns.substring(with: m.range), with: decoded)
        }
        log.append("ĐÃ GIẢI MÃ BASE64 BLOCK")
        return output
    }

    private static func stripFrameBusters(_ source: String, log: inout [String]) -> String {
        var output = source
        var changed = false
        for regex in frameBusterRegexes {
            let range = NSRange(output.startIndex..., in: output)
            let next = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "")
            if next != output { output = next; changed = true }
        }
        if changed { log.append("ĐÃ XÓA FRAME BUSTER") }
        return output
    }

    private static func extractTags(_ source: String) -> [String] {
        guard !source.isEmpty else { return [] }
        let ns = source as NSString
        let matches = tagRegex.matches(in: source, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(matches.count)
        for m in matches {
            guard m.numberOfRanges > 1 else { continue }
            let name = ns.substring(with: m.range(at: 1)).lowercased()
            if seen.insert(name).inserted { result.append(name) }
        }
        return result
    }
}
