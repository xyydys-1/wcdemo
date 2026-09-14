import Foundation
import UIKit

struct DemoArchive: Codable {
    var schemaVersion: Int = 1
    var chats: [DemoChat] = []
    var contacts: [DemoContact] = []
    var messages: [String: [DemoMessage]] = [:]
    var pinned: Set<String> = []
    var muted: Set<String> = []
    var reminders: Set<String> = []
    var wallpapers: [String: String] = [:]
    var drafts: [String: String] = [:]
    var hiddenChats: Set<String> = []
    var chatListDisplayMode: ChatListDisplayMode = .standard
    var pinnedCollapsed: Bool = false
    var directoryRevision: Int = 1

    private enum CodingKeys: String, CodingKey { case schemaVersion, chats, contacts, messages, pinned, muted, reminders, wallpapers, drafts, hiddenChats, chatListDisplayMode, pinnedCollapsed, directoryRevision }
    init(schemaVersion: Int = 1, chats: [DemoChat] = [], contacts: [DemoContact] = [], messages: [String:[DemoMessage]] = [:], pinned: Set<String> = [], muted: Set<String> = [], reminders: Set<String> = [], wallpapers: [String:String] = [:], drafts: [String:String] = [:], hiddenChats: Set<String> = [], chatListDisplayMode: ChatListDisplayMode = .standard, pinnedCollapsed: Bool = false, directoryRevision: Int = 1) {
        self.schemaVersion=schemaVersion; self.chats=chats; self.contacts=contacts; self.messages=messages; self.pinned=pinned; self.muted=muted; self.reminders=reminders; self.wallpapers=wallpapers; self.drafts=drafts; self.hiddenChats=hiddenChats; self.chatListDisplayMode=chatListDisplayMode; self.pinnedCollapsed=pinnedCollapsed; self.directoryRevision=directoryRevision
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        chats = try c.decodeIfPresent([DemoChat].self, forKey: .chats) ?? []
        contacts = try c.decodeIfPresent([DemoContact].self, forKey: .contacts) ?? []
        messages = try c.decodeIfPresent([String:[DemoMessage]].self, forKey: .messages) ?? [:]
        pinned = try c.decodeIfPresent(Set<String>.self, forKey: .pinned) ?? []
        muted = try c.decodeIfPresent(Set<String>.self, forKey: .muted) ?? []
        reminders = try c.decodeIfPresent(Set<String>.self, forKey: .reminders) ?? []
        wallpapers = try c.decodeIfPresent([String:String].self, forKey: .wallpapers) ?? [:]
        drafts = try c.decodeIfPresent([String:String].self, forKey: .drafts) ?? [:]
        hiddenChats = try c.decodeIfPresent(Set<String>.self, forKey: .hiddenChats) ?? []
        chatListDisplayMode = try c.decodeIfPresent(ChatListDisplayMode.self, forKey: .chatListDisplayMode) ?? .standard
        pinnedCollapsed = try c.decodeIfPresent(Bool.self, forKey: .pinnedCollapsed) ?? false
        directoryRevision = try c.decodeIfPresent(Int.self, forKey: .directoryRevision) ?? 1
    }
}


enum LocalStoreError: LocalizedError {
    case mediaWriteFailed
    case archiveWriteFailed
    var errorDescription: String? {
        switch self {
        case .mediaWriteFailed: return "图片保存失败"
        case .archiveWriteFailed: return "聊天记录保存失败"
        }
    }
}

final class DemoMediaStore {
    private let root: URL
    private let fm = FileManager.default
    private let cache = NSCache<NSString, UIImage>()

    init(base: URL? = nil) {
        let support = base ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        root = support.appendingPathComponent("WeChat26Demo/Media", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func image(_ key: String, maxPixel: CGFloat? = nil) -> UIImage? {
        if key.hasPrefix("asset:") {
            return UIImage(named: String(key.dropFirst(6)))
        }
        let ck = key as NSString
        if let cached = cache.object(forKey: ck) { return cached }
        let url = root.appendingPathComponent(key)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: ck)
        return image
    }

    func save(_ image: UIImage, prefix: String, maxPixel: CGFloat) throws -> String {
        let normalized = image.normalized(maxPixel: maxPixel)
        guard let data = normalized.jpegData(compressionQuality: 0.91) else { throw LocalStoreError.mediaWriteFailed }
        let name = "\(prefix)-\(UUID().uuidString).jpg"
        let url = root.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic) }
        catch { throw LocalStoreError.mediaWriteFailed }
        cache.setObject(normalized, forKey: name as NSString)
        return name
    }

    func aspect(_ key: String) -> CGFloat {
        guard let image = image(key) else { return 1 }
        return max(0.2, min(5, image.size.width / max(1, image.size.height)))
    }
}

private extension UIImage {
    func normalized(maxPixel: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let scale = min(1, maxPixel / max(w, h))
        let target = CGSize(width: max(1, w * scale), height: max(1, h * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

final class DemoPersistence {
    private let url: URL
    private let backupURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(base: URL? = nil) {
        let fm = FileManager.default
        let support = base ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("WeChat26Demo", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("notes-v1.json")
        backupURL = folder.appendingPathComponent("notes-v1.backup.json")
        encoder.outputFormatting = [.sortedKeys]
    }

    func load() -> DemoArchive? {
        for candidate in [url, backupURL] {
            if let data = try? Data(contentsOf: candidate), let value = try? decoder.decode(DemoArchive.self, from: data) {
                return value
            }
        }
        return nil
    }

    func save(_ archive: DemoArchive) throws {
        let data = try encoder.encode(archive)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: url, to: backupURL)
        }
        do { try data.write(to: url, options: .atomic) }
        catch { throw LocalStoreError.archiveWriteFailed }
    }
}
