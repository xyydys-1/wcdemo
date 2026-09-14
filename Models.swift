import SwiftUI
import Combine
import UIKit

struct DemoContact: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var symbol: String
    var colorName: String
    var subtitle: String = ""
    var avatarKey: String? = nil
}

enum DemoMessageKind: Codable, Equatable {
    case text(String), photo(String), photoStack([String]), time(String)
    private enum K: String, Codable { case text, photo, photoStack, time }
    private enum CodingKeys: String, CodingKey { case kind, text, items }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(K.self, forKey: .kind) {
        case .text: self = .text(try c.decode(String.self, forKey: .text))
        case .photo: self = .photo(try c.decode(String.self, forKey: .text))
        case .photoStack: self = .photoStack(try c.decode([String].self, forKey: .items))
        case .time: self = .time(try c.decode(String.self, forKey: .text))
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s): try c.encode(K.text, forKey: .kind); try c.encode(s, forKey: .text)
        case .photo(let s): try c.encode(K.photo, forKey: .kind); try c.encode(s, forKey: .text)
        case .photoStack(let a): try c.encode(K.photoStack, forKey: .kind); try c.encode(a, forKey: .items)
        case .time(let s): try c.encode(K.time, forKey: .kind); try c.encode(s, forKey: .text)
        }
    }
}

struct DemoMessage: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var senderID: String?
    var incoming: Bool
    var kind: DemoMessageKind
}

struct DemoChat: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var time: String
    var unread: Int
    var avatarSymbol: String
    var avatarColorName: String
    var isGroup: Bool = false
    var memberIDs: [String] = []
    var avatarKey: String? = nil
    private enum CodingKeys: String, CodingKey { case id,title,subtitle,time,unread,avatarSymbol,avatarColorName,isGroup,memberIDs,avatarKey }
    init(id:String,title:String,subtitle:String,time:String,unread:Int,avatarSymbol:String,avatarColorName:String,isGroup:Bool=false,memberIDs:[String]=[],avatarKey:String?=nil){self.id=id;self.title=title;self.subtitle=subtitle;self.time=time;self.unread=unread;self.avatarSymbol=avatarSymbol;self.avatarColorName=avatarColorName;self.isGroup=isGroup;self.memberIDs=memberIDs;self.avatarKey=avatarKey}
    init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decode(String.self,forKey:.id); title=try c.decode(String.self,forKey:.title); subtitle=try c.decodeIfPresent(String.self,forKey:.subtitle) ?? ""; time=try c.decodeIfPresent(String.self,forKey:.time) ?? ""; unread=try c.decodeIfPresent(Int.self,forKey:.unread) ?? 0; avatarSymbol=try c.decodeIfPresent(String.self,forKey:.avatarSymbol) ?? "person.fill"; avatarColorName=try c.decodeIfPresent(String.self,forKey:.avatarColorName) ?? "gray"; isGroup=try c.decodeIfPresent(Bool.self,forKey:.isGroup) ?? false; memberIDs=try c.decodeIfPresent([String].self,forKey:.memberIDs) ?? []; avatarKey=try c.decodeIfPresent(String.self,forKey:.avatarKey)
    }
}

enum ChatListDisplayMode: String, Codable, CaseIterable, Identifiable {
    case standard, compact
    var id: String { rawValue }
    var title: String { self == .standard ? "默认" : "紧凑" }
}

@MainActor
final class DemoStore: ObservableObject {
    @Published private(set) var state: DemoArchive
    let media = DemoMediaStore()
    private let persistence = DemoPersistence()
    @Published var lastError: String?

    init() {
        state = persistence.load() ?? DemoSeed.make()
        normalize()
        saveQuietly()
    }

    var chats: [DemoChat] { state.chats.filter { !state.hiddenChats.contains($0.id) } }
    var contacts: [DemoContact] { state.contacts }
    var messages: [String: [DemoMessage]] { state.messages }
    var pinned: Set<String> { state.pinned }
    var muted: Set<String> { state.muted }
    var chatListDisplayMode: ChatListDisplayMode { state.chatListDisplayMode }
    var pinnedCollapsed: Bool { state.pinnedCollapsed }

    func chat(_ id: String) -> DemoChat {
        state.chats.first(where: { $0.id == id }) ?? DemoChat(id: id, title: "聊天", subtitle: "", time: "", unread: 0, avatarSymbol: "person.fill", avatarColorName: "gray")
    }
    func contact(_ id: String) -> DemoContact? { state.contacts.first(where: { $0.id == id }) }
    func profileName(_ id: String) -> String {
        if id == "me" { return UserDefaults.standard.string(forKey: "demo.self.name") ?? "xyy" }
        return contact(id)?.name ?? chat(id).title
    }
    func profileAvatarKey(_ id: String) -> String? {
        if id == "me" { return UserDefaults.standard.string(forKey: "demo.self.avatar") }
        return contact(id)?.avatarKey
    }
    func wallpaperKey(_ chatID: String) -> String? { state.wallpapers[chatID] }
    func draft(_ chatID: String) -> String { state.drafts[chatID] ?? "" }

    func setDraft(_ value: String, chatID: String) { change { $0.drafts[chatID] = value } }
    func sendText(_ text: String, to chatID: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }
        change {
            $0.messages[chatID, default: []].append(DemoMessage(senderID: "me", incoming: false, kind: .text(value)))
            if let i = $0.chats.firstIndex(where: { $0.id == chatID }) { $0.chats[i].subtitle = value; $0.chats[i].time = "刚刚" }
            $0.drafts[chatID] = ""
        }
    }
    func sendPhotos(_ keys: [String], to chatID: String) {
        guard !keys.isEmpty else { return }
        change {
            let kind: DemoMessageKind = keys.count == 1 ? .photo(keys[0]) : .photoStack(keys)
            $0.messages[chatID, default: []].append(DemoMessage(senderID: "me", incoming: false, kind: kind))
            if let i = $0.chats.firstIndex(where: { $0.id == chatID }) { $0.chats[i].subtitle = "[图片]"; $0.chats[i].time = "刚刚" }
        }
    }
    func importPhotos(_ images: [UIImage], chatID: String) {
        do { sendPhotos(try images.map { try media.save($0, prefix: "photo", maxPixel: 2048) }, to: chatID) }
        catch { lastError = error.localizedDescription }
    }
    func setWallpaper(_ image: UIImage, chatID: String) {
        do { let key = try media.save(image, prefix: "wall", maxPixel: 2400); change { $0.wallpapers[chatID] = key } }
        catch { lastError = error.localizedDescription }
    }
    func updateContact(_ id: String, name: String, avatar: UIImage?) {
        do {
            let key = try avatar.map { try media.save($0, prefix: "avatar", maxPixel: 512) }
            change { a in
                if let i = a.contacts.firstIndex(where: { $0.id == id }) { a.contacts[i].name = name; if let key { a.contacts[i].avatarKey = key } }
                if let i = a.chats.firstIndex(where: { $0.id == id }) { a.chats[i].title = name; if let key { a.chats[i].avatarKey = key } }
            }
        } catch { lastError = error.localizedDescription }
    }
    func updateSelf(name: String, avatar: UIImage?) {
        UserDefaults.standard.set(name, forKey: "demo.self.name")
        if let avatar, let key = try? media.save(avatar, prefix: "self", maxPixel: 512) { UserDefaults.standard.set(key, forKey: "demo.self.avatar") }
        objectWillChange.send()
    }
    func updateGroup(_ id: String, name: String, avatar: UIImage?) {
        do {
            let key = try avatar.map { try media.save($0, prefix: "group", maxPixel: 512) }
            change { a in if let i = a.chats.firstIndex(where: { $0.id == id }) { a.chats[i].title = name; if let key { a.chats[i].avatarKey = key } } }
        } catch { lastError = error.localizedDescription }
    }
    func addContact(name: String, avatar: UIImage?) {
        let id = "friend-\(UUID().uuidString.lowercased())"
        var key: String?; if let avatar { key = try? media.save(avatar, prefix: "avatar", maxPixel: 512) }
        change { $0.contacts.append(DemoContact(id: id, name: name, symbol: "person.fill", colorName: "blue", avatarKey: key)) }
    }
    func addGroupMembers(_ ids: [String], to chatID: String) {
        change { a in guard let i = a.chats.firstIndex(where: { $0.id == chatID }) else { return }; for id in ids where !a.chats[i].memberIDs.contains(id) { a.chats[i].memberIDs.append(id) } }
    }
    func removeGroupMember(_ id: String, from chatID: String) { change { a in if let i = a.chats.firstIndex(where: { $0.id == chatID }) { a.chats[i].memberIDs.removeAll { $0 == id } } } }
    func ensureDirectChat(_ contactID: String) -> String {
        if state.chats.contains(where: { $0.id == contactID }) { return contactID }
        guard let c = contact(contactID) else { return contactID }
        change { a in
            a.chats.insert(DemoChat(id: contactID, title: c.name, subtitle: "", time: "", unread: 0, avatarSymbol: c.symbol, avatarColorName: c.colorName, avatarKey: c.avatarKey), at: 0)
            if a.messages[contactID] == nil { a.messages[contactID] = [] }
        }
        return contactID
    }
    func createGroup(memberIDs: [String]) -> String {
        let id = "group-\(UUID().uuidString.lowercased())"
        change {
            $0.chats.insert(DemoChat(id: id, title: "群聊", subtitle: "你已创建群聊", time: "刚刚", unread: 0, avatarSymbol: "person.3.fill", avatarColorName: "green", isGroup: true, memberIDs: ["me"] + memberIDs), at: 0)
            $0.messages[id] = [DemoMessage(senderID: nil, incoming: false, kind: .time("刚刚"))]
        }
        return id
    }
    func deleteChat(_ id: String) { change { $0.chats.removeAll { $0.id == id }; $0.messages.removeValue(forKey: id) } }
    func deleteContact(_ id: String) { change { $0.contacts.removeAll { $0.id == id } } }
    func clearChat(_ id: String) { change { $0.messages[id] = []; $0.drafts[id] = "" } }
    func setPinned(_ value: Bool, for id: String) { change { if value { $0.pinned.insert(id) } else { $0.pinned.remove(id) } } }
    func setMuted(_ value: Bool, for id: String) { change { if value { $0.muted.insert(id) } else { $0.muted.remove(id) } } }
    func setDisplayMode(_ mode: ChatListDisplayMode) { change { $0.chatListDisplayMode = mode } }
    func setPinnedCollapsed(_ v: Bool) { change { $0.pinnedCollapsed = v } }
    func flush() { saveQuietly() }

    private func normalize() {
        for i in state.chats.indices where state.chats[i].isGroup && state.chats[i].memberIDs.isEmpty { state.chats[i].memberIDs = ["me","xixi","shore"] }
    }
    private func change(_ body: (inout DemoArchive) -> Void) { body(&state); objectWillChange.send(); saveQuietly() }
    private func saveQuietly() { do { try persistence.save(state) } catch { lastError = error.localizedDescription } }
}

struct DemoAvatar: View {
    var symbol: String
    var colorName: String
    var size: CGFloat = 48
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(Color.demo(colorName).gradient)
            Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white)
        }.frame(width: size, height: size)
    }
}

struct ProfileAvatar: View {
    @EnvironmentObject private var store: DemoStore
    let id: String
    var size: CGFloat = 48
    var body: some View {
        Group {
            if let key = store.profileAvatarKey(id), let image = store.media.image(key) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if id == "me" {
                DemoAvatar(symbol: "person.crop.circle.fill", colorName: "blue", size: size)
            } else if let c = store.contact(id) {
                DemoAvatar(symbol: c.symbol, colorName: c.colorName, size: size)
            } else { DemoAvatar(symbol: "person.fill", colorName: "gray", size: size) }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

extension Color {
    static let wxGreen = Color(red: 0.09, green: 0.78, blue: 0.34)
    static let wxBubbleGreen = Color(red: 0.58, green: 0.94, blue: 0.47)
    static func demo(_ name: String) -> Color {
        switch name { case "pink": return .pink; case "blue": return .blue; case "indigo": return .indigo; case "teal": return .teal; case "orange": return .orange; case "purple": return .purple; case "cyan": return .cyan; case "green": return .green; case "red": return .red; default: return .gray }
    }
}
