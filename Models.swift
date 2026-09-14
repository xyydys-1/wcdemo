import SwiftUI
import Combine
import UIKit
import PhotosUI

@MainActor
final class DemoStore: ObservableObject {
    @Published private(set) var state = DemoArchive()
    @Published var errorMessage: String?
    let media: LocalMediaFiles
    private let archiveFile: LocalArchiveFile
    private var writable = true
    private var pendingDrafts: [String: String] = [:]
    private var draftWork: Task<Void, Never>?
    var chats: [DemoChat] { state.chats }
    var contacts: [DemoContact] { state.contacts }
    var messages: [String: [DemoMessage]] { state.messages }
    var pinned: Set<String> { state.pinned }
    var muted: Set<String> { state.muted }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WeChat26Demo", isDirectory: true)
        archiveFile = LocalArchiveFile(directory: base)
        media = LocalMediaFiles(directory: base.appendingPathComponent("Media", isDirectory: true))
        do {
            if let saved = try archiveFile.load() {
                state = saved.archive
                var migrated = saved.archive
                if DemoHistoryMigration.apply(to: &migrated) {
                    try archiveFile.save(migrated)
                    state = migrated
                }
                if saved.recovered { errorMessage = "已从上一次完整保存中恢复本地记录。" }
            } else {
                let initial = DemoSeed.make()
                try archiveFile.save(initial)
                state = initial
            }
        } catch {
            writable = false
            errorMessage = error.localizedDescription
        }
    }

    // A successful send means the complete transaction is already on disk.
    @discardableResult
    private func change(_ edit: (inout DemoArchive) -> Void) -> Bool {
        guard writable else {
            errorMessage = "本地记录尚未成功读取，已停止覆盖写入。请保留应用数据并重新打开。"
            return false
        }
        var next = state
        for (key, draft) in pendingDrafts { next.drafts[key] = draft }
        edit(&next)
        do {
            try archiveFile.save(next)
            draftWork?.cancel(); draftWork = nil; pendingDrafts.removeAll()
            state = next
            return true
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            return false
        }
    }

    func chat(_ id: String) -> DemoChat {
        if let chat = chats.first(where: { $0.id == id }) { return chat }
        let person = profile(id)
        return DemoChat(id: id, title: person.name, subtitle: "", time: "", unread: 0,
                        avatarSymbol: person.symbol, avatarColor: person.tint, avatarKey: person.avatarKey)
    }
    func contact(_ id: String) -> DemoContact? {
        if id == "me" { return state.me }
        return contacts.first { $0.id == id }
    }
    func profile(_ id: String) -> DemoContact {
        if let contact = contact(id) { return contact }
        if let chat = chats.first(where: { $0.id == id }) {
            return DemoContact(id: id, name: chat.title, symbol: chat.avatarSymbol,
                               color: chat.avatarTint, avatarKey: chat.avatarKey)
        }
        return DemoContact(id: id, name: "联系人", symbol: "person.fill", color: .gray)
    }
    func preview(for chat: DemoChat) -> String {
        guard let last = messages[chat.id]?.last(where: { !$0.kind.summary.isEmpty }) else { return "" }
        let prefix = chat.isGroup && last.incoming ? "\(profile(last.senderID ?? "").name)：" : ""
        return prefix + last.kind.summary
    }
    private func ensureChat(_ id: String, in next: inout DemoArchive) {
        guard !next.chats.contains(where: { $0.id == id }) else { return }
        let person = profile(id)
        next.chats.insert(DemoChat(id: id, title: person.name, subtitle: "", time: "", unread: 0,
                                   avatarSymbol: person.symbol, avatarColor: person.tint,
                                   avatarKey: person.avatarKey), at: 0)
    }
    func openChat(_ id: String) {
        let existing = chats.first { $0.id == id }
        guard existing == nil || existing?.unread != 0 || state.hiddenChats.contains(id) else { return }
        change { next in
            ensureChat(id, in: &next)
            if let i = next.chats.firstIndex(where: { $0.id == id }) { next.chats[i].unread = 0 }
            next.hiddenChats.remove(id)
        }
    }
    @discardableResult
    func sendText(_ text: String, to id: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        return append(.text(value), to: id, clearDraft: true)
    }
    @discardableResult
    func sendPhotos(_ keys: [String], to id: String) -> Bool {
        guard !keys.isEmpty else { return false }
        return append(keys.count == 1 ? .photo(keys[0]) : .photoStack(keys), to: id)
    }
    private func append(_ kind: DemoMessageKind, to id: String, clearDraft: Bool = false) -> Bool {
        change { next in
            ensureChat(id, in: &next)
            let now = Date()
            if next.messages[id]?.last.map({ now.timeIntervalSince($0.createdAt) > 300 }) ?? true {
                let formatter = DateFormatter(); formatter.dateFormat = "M月d日 HH:mm"
                next.messages[id, default: []].append(DemoMessage(senderID: nil, incoming: false,
                    kind: .time(formatter.string(from: now)), createdAt: now))
            }
            next.messages[id, default: []].append(DemoMessage(senderID: "me", incoming: false, kind: kind, createdAt: now))
            if clearDraft { next.drafts[id] = "" }
            next.hiddenChats.remove(id)
            if let index = next.chats.firstIndex(where: { $0.id == id }) {
                var chat = next.chats.remove(at: index)
                let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
                chat.subtitle = kind.summary; chat.time = formatter.string(from: now); chat.unread = 0
                next.chats.insert(chat, at: 0)
            }
        }
    }
    func draft(for id: String) -> String { pendingDrafts[id] ?? state.drafts[id] ?? "" }
    func setDraft(_ text: String, for id: String) {
        guard draft(for: id) != text else { return }
        pendingDrafts[id] = text
        draftWork?.cancel()
        draftWork = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            if let self { self.flush() }
        }
    }
    func flush() {
        guard !pendingDrafts.isEmpty else { return }
        change { _ in }
    }
    @discardableResult
    func saveProfile(id: String, name: String, avatarKey: String?) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        return change { next in
            if id == "me" { next.me.name = name; next.me.avatarKey = avatarKey }
            else if let i = next.contacts.firstIndex(where: { $0.id == id }) {
                next.contacts[i].name = name; next.contacts[i].avatarKey = avatarKey
            } else if !id.isEmpty, next.chats.first(where: { $0.id == id })?.isGroup != true {
                var person = profile(id); person.name = name; person.avatarKey = avatarKey
                next.contacts.append(person)
            }
            if let i = next.chats.firstIndex(where: { $0.id == id }) {
                next.chats[i].title = name; next.chats[i].avatarKey = avatarKey
            }
        }
    }
    func setPinned(_ value: Bool, for id: String) {
        change { if value { $0.pinned.insert(id) } else { $0.pinned.remove(id) } }
    }
    func setMuted(_ value: Bool, for id: String) {
        change { if value { $0.muted.insert(id) } else { $0.muted.remove(id) } }
    }
    func setReminder(_ value: Bool, for id: String) {
        change { if value { $0.reminders.insert(id) } else { $0.reminders.remove(id) } }
    }
    @discardableResult
    func setWallpaper(_ key: String?, for id: String) -> Bool { change { $0.wallpapers[id] = key } }
    func hideChat(_ id: String) { change { $0.hiddenChats.insert(id) } }
    func clearMessages(_ id: String) {
        change { next in
            next.messages[id] = []; next.drafts[id] = ""
            if let i = next.chats.firstIndex(where: { $0.id == id }) {
                next.chats[i].subtitle = ""; next.chats[i].unread = 0; next.chats[i].time = ""
            }
        }
    }
    func deleteChat(_ id: String) {
        change { next in
            next.chats.removeAll { $0.id == id }; next.messages.removeValue(forKey: id)
            next.drafts.removeValue(forKey: id); next.wallpapers.removeValue(forKey: id)
            next.pinned.remove(id); next.muted.remove(id); next.reminders.remove(id); next.hiddenChats.remove(id)
        }
    }
    func deleteContact(_ id: String) { change { $0.contacts.removeAll { $0.id == id } } }

    @discardableResult
    func addFriend(account: String, name: String = "") -> String? {
        let account = account.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty else { return nil }
        if contacts.contains(where: { $0.subtitle.caseInsensitiveCompare(account) == .orderedSame }) {
            errorMessage = "这个账号已经在通讯录中了。"
            return nil
        }
        let id = "friend-" + UUID().uuidString
        let displayName = requestedName.isEmpty ? account : requestedName
        let palette: [DemoTint] = [.blue, .pink, .teal, .purple, .orange, .indigo, .cyan, .green]
        let symbols = ["person.fill", "sparkles", "leaf.fill", "star.fill", "flame.fill", "moon.stars.fill", "heart.fill", "circle.fill"]
        let index = contacts.count % palette.count
        let saved = change { next in
            next.contacts.append(DemoContact(id: id, name: displayName, symbol: symbols[index],
                                             color: palette[index], subtitle: account))
        }
        return saved ? id : nil
    }

    func createGroup(memberIDs: [String]) -> String? {
        let id = "group-" + UUID().uuidString
        let members = ["me"] + contacts.filter { memberIDs.contains($0.id) }.map(\.id)
        guard members.count > 1 else { return nil }
        let saved = change { next in
            next.chats.insert(DemoChat(id: id, title: "群聊", subtitle: "", time: "", unread: 0,
                avatarSymbol: "person.3.fill", avatarColor: .green, isGroup: true, memberIDs: members), at: 0)
            next.messages[id] = [DemoMessage(senderID: nil, incoming: false, kind: .time("你已创建群聊"))]
        }
        return saved ? id : nil
    }

    @discardableResult
    func addMembers(_ memberIDs: [String], toGroup groupID: String) -> Bool {
        guard let group = chats.first(where: { $0.id == groupID && $0.isGroup }) else { return false }
        let existing = Set(group.memberIDs)
        let contactIDs = Set(contacts.map(\.id))
        let additions = memberIDs.filter { $0 != "me" && contactIDs.contains($0) && !existing.contains($0) }
        guard !additions.isEmpty else { return false }
        let names = additions.map { profile($0).name }.joined(separator: "、")
        return change { next in
            guard let index = next.chats.firstIndex(where: { $0.id == groupID && $0.isGroup }) else { return }
            next.chats[index].memberIDs.append(contentsOf: additions)
            next.messages[groupID, default: []].append(
                DemoMessage(senderID: nil, incoming: false, kind: .time("你邀请\(names)加入了群聊"))
            )
        }
    }

    func importImage(_ data: Data, maxPixel: Int = 2048) async throws -> String {
        let files = media
        return try await Task.detached(priority: .userInitiated) {
            try files.importImage(data, maxPixel: maxPixel)
        }.value
    }
    func importPhotos(_ items: [PhotosPickerItem], to id: String) async -> Bool {
        var keys: [String] = []
        do {
            for item in items {
                try Task.checkCancellation()
                guard let data = try await item.loadTransferable(type: Data.self) else { throw LocalDataError.invalidImage }
                keys.append(try await importImage(data))
            }
            try Task.checkCancellation()
            guard sendPhotos(keys, to: id) else {
                keys.forEach { media.removeUnreferencedImport($0) }; return false
            }
            return true
        } catch {
            keys.forEach { media.removeUnreferencedImport($0) }
            if !(error is CancellationError) { errorMessage = "照片未发送：\(error.localizedDescription)" }
            return false
        }
    }
}

extension DemoTint {
    var color: Color {
        switch self {
        case .pink: return .pink
        case .blue: return .blue
        case .indigo: return .indigo
        case .teal: return .teal
        case .orange: return .orange
        case .purple: return .purple
        case .cyan: return .cyan
        case .green: return .green
        case .red: return .red
        case .gray: return .gray
        }
    }
}
extension DemoContact { var color: Color { tint.color } }
extension DemoChat { var avatarColor: Color { avatarTint.color } }

struct DemoAvatar: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 48
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(color.gradient)
            Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size, alignment: .center).foregroundStyle(.white)
        }.frame(width: size, height: size)
    }
}

struct ProfileAvatar: View {
    @EnvironmentObject private var store: DemoStore
    let id: String
    var size: CGFloat = 48
    var body: some View {
        let person = store.profile(id)
        let group = store.chats.first(where: { $0.id == id && $0.isGroup })
        Group {
            if let key = person.avatarKey, let image = store.media.image(key, maxPixel: 256) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let group, !group.memberIDs.isEmpty {
                groupAvatar(group)
            } else { DemoAvatar(symbol: person.symbol, color: person.color, size: size) }
        }
        .frame(width: size, height: size)
        // Group mosaics keep a slightly tighter outer radius than a single avatar.
        // The whole mosaic is clipped as one silhouette, matching the supplied reference.
        .clipShape(RoundedRectangle(cornerRadius: size * (group == nil ? 0.24 : 0.18), style: .continuous))
        .accessibilityLabel(person.name + "的头像")
    }
    private func groupAvatar(_ chat: DemoChat) -> some View {
        let ids = Array(chat.memberIDs.prefix(4))
        let gap: CGFloat = 2
        let side = (size - gap) / 2
        return LazyVGrid(columns: [GridItem(.fixed(side), spacing: gap), GridItem(.fixed(side), spacing: gap)], spacing: gap) {
            ForEach(ids, id: \.self) { member in
                let person = store.profile(member)
                Group {
                    if let key = person.avatarKey, let image = store.media.image(key, maxPixel: 128) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else { DemoAvatar(symbol: person.symbol, color: person.color, size: side) }
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.20, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .background(Color(uiColor: .tertiarySystemFill))
    }
}

extension Color {
    static let wxGreen = Color(red: 0.09, green: 0.78, blue: 0.34)
    static let wxBubbleGreen = Color(red: 0.58, green: 0.94, blue: 0.47)
}
