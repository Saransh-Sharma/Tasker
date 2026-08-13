import Foundation
import LifeBoardDomain

public actor ProtectedKnowledgeAttachmentFiles: KnowledgeAttachmentFileRepository {
    private let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.rootURL = support
                .appendingPathComponent("LifeBoard", isDirectory: true)
                .appendingPathComponent("KnowledgeAttachments", isDirectory: true)
        }
    }

    public func persist(_ attachment: KnowledgeAttachmentValue) async throws -> URL {
        guard attachment.payload.isEmpty == false else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: "The attachment has no readable data."])
        }
        let directory = rootURL.appendingPathComponent(attachment.id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = URL(fileURLWithPath: attachment.fileName).lastPathComponent
        let url = directory.appendingPathComponent(fileName.isEmpty ? "Attachment" : fileName, isDirectory: false)
        try attachment.payload.write(to: url, options: [.atomic, .completeFileProtection])
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        return url
    }

    public func resolvedURL(for attachment: KnowledgeAttachmentValue) async throws -> URL {
        let directory = rootURL.appendingPathComponent(attachment.id.uuidString, isDirectory: true)
        if let existing = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).first, fileManager.fileExists(atPath: existing.path) {
            return existing
        }
        return try await persist(attachment)
    }

    public func deleteFile(for attachment: KnowledgeAttachmentValue) async throws {
        let directory = rootURL.appendingPathComponent(attachment.id.uuidString, isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }
}

public actor URLSessionKnowledgeBookmarkMetadataFetcher: KnowledgeBookmarkMetadataFetching {
    public static let shared = URLSessionKnowledgeBookmarkMetadataFetcher()

    public func metadata(for url: URL) async throws -> KnowledgeBlockPayload.Bookmark {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw URLError(.unsupportedURL)
        }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<400).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return Self.parseHTML(Data(data.prefix(262_144)), url: http.url ?? url)
    }

    public nonisolated static func parseHTML(_ data: Data, url: URL) -> KnowledgeBlockPayload.Bookmark {
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return .init(url: url)
        }
        let metadata = metaAttributes(in: html)
        let title = metadata["og:title"]
            ?? metadata["twitter:title"]
            ?? firstCapture(in: html, pattern: #"(?is)<title[^>]*>(.*?)</title>"#)
        let summary = metadata["og:description"]
            ?? metadata["twitter:description"]
            ?? metadata["description"]
        return .init(url: url, title: cleaned(title), summary: cleaned(summary))
    }

    private nonisolated static func metaAttributes(in html: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<meta\s+[^>]*>"#) else { return [:] }
        let range = NSRange(html.startIndex..., in: html)
        var result: [String: String] = [:]
        for match in regex.matches(in: html, range: range) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tag = String(html[tagRange])
            let key = attribute("property", in: tag) ?? attribute("name", in: tag)
            if let key, let content = attribute("content", in: tag) {
                result[key.lowercased()] = content
            }
        }
        return result
    }

    private nonisolated static func attribute(_ name: String, in tag: String) -> String? {
        firstCapture(in: tag, pattern: "(?is)\\b\(NSRegularExpression.escapedPattern(for: name))\\s*=\\s*[\\\"']([^\\\"']*)[\\\"']")
    }

    private nonisolated static func firstCapture(in value: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range])
    }

    private nonisolated static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let withoutTags = value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let decoded = withoutTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        let compact = decoded.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return compact.isEmpty ? nil : compact
    }
}
