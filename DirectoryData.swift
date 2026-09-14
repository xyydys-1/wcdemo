import Foundation

enum ChatListDisplayMode: String, Codable, CaseIterable {
    case standard, compact
    var title: String { self == .standard ? "默认" : "紧凑" }
}

enum DemoDirectory {
    static let revision = 1
    static let extraContacts: [DemoContact] = [
        DemoContact(id: "jinhsi", name: "今汐", symbol: "person.fill", color: .cyan),
        DemoContact(id: "yinlin", name: "吟霖", symbol: "person.fill", color: .red),
        DemoContact(id: "yangyang", name: "秧秧", symbol: "person.fill", color: .blue),
        DemoContact(id: "chixia", name: "炽霞", symbol: "person.fill", color: .orange),
        DemoContact(id: "baizhi", name: "白芷", symbol: "person.fill", color: .teal),
        DemoContact(id: "sanhua", name: "散华", symbol: "person.fill", color: .indigo),
        DemoContact(id: "encore", name: "安可", symbol: "person.fill", color: .pink),
        DemoContact(id: "verina", name: "维里奈", symbol: "person.fill", color: .green),
        DemoContact(id: "jiyan", name: "忌炎", symbol: "person.fill", color: .teal),
        DemoContact(id: "danjin", name: "丹瑾", symbol: "person.fill", color: .red),
        DemoContact(id: "lingyang", name: "凌阳", symbol: "person.fill", color: .purple),
        DemoContact(id: "mortefi", name: "莫特斐", symbol: "person.fill", color: .orange)
    ]

    @discardableResult
    static func upgrade(_ archive: inout DemoArchive) -> Bool {
        guard (archive.directoryRevision ?? 0) < revision else { return false }
        // Respect an intentionally emptied address book. Existing profiles and
        // groups, including renamed examples, are never replaced.
        if !archive.contacts.isEmpty {
            let existing = Set(archive.contacts.map(\.id))
                .union(archive.chats.map(\.id))
            archive.contacts += extraContacts.filter { !existing.contains($0.id) }
        }
        archive.directoryRevision = revision
        return true
    }

    @discardableResult
    static func addMembers(_ ids: [String], to groupID: String, in archive: inout DemoArchive) -> Bool {
        guard let index = archive.chats.firstIndex(where: { $0.id == groupID && $0.isGroup }) else { return false }
        let valid = Set(archive.contacts.map(\.id)).union(["me"])
        var members = archive.chats[index].memberIDs
        for id in ids where valid.contains(id) && !members.contains(id) { members.append(id) }
        guard members != archive.chats[index].memberIDs else { return false }
        archive.chats[index].memberIDs = members
        return true
    }
}
