import Foundation

// Foundation-only models: the same archive is exercised by Tests/LocalDataTests.swift.
enum DemoTint: String, Codable {
    case pink, blue, indigo, teal, orange, purple, cyan, green, red, gray
}

struct DemoContact: Identifiable, Codable {
    let id: String
    var name: String
    var symbol: String
    var tint: DemoTint
    var subtitle: String
    var avatarKey: String?

    init(id: String, name: String, symbol: String, color: DemoTint,
         subtitle: String = "", avatarKey: String? = nil) {
        self.id = id; self.name = name; self.symbol = symbol; self.tint = color
        self.subtitle = subtitle; self.avatarKey = avatarKey
    }
}

enum DemoMessageKind: Codable {
    case text(String)
    case photo(String)
    case photoStack([String])
    case time(String)

    var summary: String {
        switch self {
        case .text(let text): return text
        case .photo: return "[图片]"
        case .photoStack(let images): return "[\(images.count)张图片]"
        case .time: return ""
        }
    }

    var photoKeys: [String] {
        switch self {
        case .photo(let key): return [key]
        case .photoStack(let keys): return keys
        default: return []
        }
    }
}

struct DemoMessage: Identifiable, Codable {
    let id: UUID
    var senderID: String?
    var incoming: Bool
    var kind: DemoMessageKind
    var createdAt: Date

    init(id: UUID = UUID(), senderID: String?, incoming: Bool,
         kind: DemoMessageKind, createdAt: Date = Date()) {
        self.id = id; self.senderID = senderID; self.incoming = incoming
        self.kind = kind; self.createdAt = createdAt
    }
}

struct DemoChat: Identifiable, Codable {
    let id: String
    var title: String
    var subtitle: String
    var time: String
    var unread: Int
    var avatarSymbol: String
    var avatarTint: DemoTint
    var isGroup: Bool
    var avatarKey: String?
    var memberIDs: [String]

    init(id: String, title: String, subtitle: String, time: String, unread: Int,
         avatarSymbol: String, avatarColor: DemoTint, isGroup: Bool = false,
         avatarKey: String? = nil, memberIDs: [String] = []) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.time = time
        self.unread = unread; self.avatarSymbol = avatarSymbol; self.avatarTint = avatarColor
        self.isGroup = isGroup; self.avatarKey = avatarKey; self.memberIDs = memberIDs
    }
}

struct DemoArchive: Codable {
    var schemaVersion = 1
    // Optional for decoding 0.3.0 archives without resetting any user data.
    var demoContentRevision: Int?
    var directoryRevision: Int?
    var chatListDisplayMode: ChatListDisplayMode?
    var pinnedCollapsed: Bool?
    var compactAttachmentMenu: Bool?
    var chats: [DemoChat] = []
    var contacts: [DemoContact] = []
    var me = DemoContact(id: "me", name: "漂泊者", symbol: "person.fill", color: .blue)
    var messages: [String: [DemoMessage]] = [:]
    var pinned: Set<String> = []
    var muted: Set<String> = []
    var reminders: Set<String> = []
    var wallpapers: [String: String] = [:]
    var drafts: [String: String] = [:]
    var hiddenChats: Set<String> = []
}

enum LocalDataError: LocalizedError {
    case unreadableArchive, unsupportedVersion, invalidImage, invalidKey
    var errorDescription: String? {
        switch self {
        case .unreadableArchive: return "本地记录暂时无法读取，原文件已保留，没有重新初始化。"
        case .unsupportedVersion: return "这些记录由更新版本保存，请使用相同或更高版本打开。"
        case .invalidImage: return "无法读取这张照片，请重新选择。"
        case .invalidKey: return "找不到对应的本地图片。"
        }
    }
}

final class LocalArchiveFile {
    let directory: URL
    var archiveURL: URL { directory.appendingPathComponent("notes-v1.json") }
    var backupURL: URL { directory.appendingPathComponent("notes-v1.backup.json") }

    init(directory: URL) { self.directory = directory }

    // nil means first install only. Empty chats/messages are valid saved user data.
    func load() throws -> (archive: DemoArchive, recovered: Bool)? {
        let fm = FileManager.default
        let hasCurrent = fm.fileExists(atPath: archiveURL.path)
        let hasBackup = fm.fileExists(atPath: backupURL.path)
        guard hasCurrent || hasBackup else { return nil }
        if hasCurrent, let data = try? Data(contentsOf: archiveURL) {
            do { return (try decode(data), false) }
            catch LocalDataError.unsupportedVersion { throw LocalDataError.unsupportedVersion }
            catch { /* Try the last complete revision without touching either file. */ }
        }
        if hasBackup, let data = try? Data(contentsOf: backupURL) {
            do { return (try decode(data), true) }
            catch LocalDataError.unsupportedVersion { throw LocalDataError.unsupportedVersion }
            catch { }
        }
        throw LocalDataError.unreadableArchive
    }

    func save(_ archive: DemoArchive) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(archive)
        // Never promote a damaged current file into the recovery slot.
        if let old = try? Data(contentsOf: archiveURL), (try? decode(old)) != nil {
            try old.write(to: backupURL, options: .atomic)
        }
        try data.write(to: archiveURL, options: .atomic)
    }

    private func decode(_ data: Data) throws -> DemoArchive {
        struct VersionHeader: Decodable { let schemaVersion: Int }
        let decoder = JSONDecoder()
        let header = try decoder.decode(VersionHeader.self, from: data)
        guard header.schemaVersion == 1 else { throw LocalDataError.unsupportedVersion }
        return try decoder.decode(DemoArchive.self, from: data)
    }
}
