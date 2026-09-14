import Foundation

extension LocalDataTests {
    static func directoryTests() throws {
        var legacy = DemoSeed.make()
        let addedIDs = Set(DemoDirectory.extraContacts.map(\.id))
        legacy.contacts.removeAll { addedIDs.contains($0.id) }
        legacy.directoryRevision = nil
        legacy.chatListDisplayMode = nil
        legacy.pinnedCollapsed = nil
        legacy.compactAttachmentMenu = nil
        legacy.me.name = "已保存的昵称"
        legacy.me.avatarKey = "local:my-avatar.jpg"
        legacy.contacts[0].name = "我改过的备注"
        legacy.contacts[0].avatarKey = "local:friend-avatar.jpg"
        legacy.chats[0].title = "自定义群名"
        legacy.chats[0].avatarKey = "local:group-avatar.jpg"
        legacy.messages["family"] = []
        legacy.messages["xixi", default: []].append(DemoMessage(senderID: "me", incoming: false,
            kind: .photoStack(["local:a.jpg", "local:b.jpg"])))
        legacy.wallpapers["xixi"] = "local:wallpaper.jpg"
        legacy.drafts["xixi"] = "未发出的草稿"
        legacy.pinned = ["xixi"]
        legacy.muted = ["family"]

        // Old JSON genuinely omits the new fields, matching the installed 0.3.2
        // archive rather than relying on a freshly initialized Swift instance.
        var object = try require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        for key in ["directoryRevision", "chatListDisplayMode", "pinnedCollapsed", "compactAttachmentMenu"] {
            object.removeValue(forKey: key)
        }
        var loaded = try JSONDecoder().decode(DemoArchive.self, from: JSONSerialization.data(withJSONObject: object))
        try expect(loaded.chatListDisplayMode == nil && loaded.pinnedCollapsed == nil,
                   "An old archive decodes without the new optional preferences")
        try expect(DemoDirectory.upgrade(&loaded), "A saved directory upgrades once")
        try expect(loaded.contacts.count == legacy.contacts.count + 12, "Twelve additional example friends are appended")
        var preserved = loaded
        preserved.contacts.removeAll { addedIDs.contains($0.id) }
        preserved.directoryRevision = nil
        try expect(try canonical(preserved) == canonical(legacy),
                   "Directory expansion preserves existing names, avatars, group rosters, messages, cleared chats and settings")

        loaded.contacts.removeAll { $0.id == "jinhsi" }
        try expect(!DemoDirectory.upgrade(&loaded) && !loaded.contacts.contains { $0.id == "jinhsi" },
                   "A removed example friend is not recreated on the next launch")
        var empty = legacy
        empty.contacts = []
        _ = DemoDirectory.upgrade(&empty)
        try expect(empty.contacts.isEmpty, "An intentionally emptied address book remains empty")

        var collision = legacy
        collision.contacts.append(DemoContact(id: "jinhsi", name: "我自己的今汐", symbol: "person.fill",
                                             color: .blue, avatarKey: "local:custom.jpg"))
        _ = DemoDirectory.upgrade(&collision)
        let matched = collision.contacts.filter { $0.id == "jinhsi" }
        try expect(matched.count == 1 && matched[0].name == "我自己的今汐" && matched[0].avatarKey == "local:custom.jpg",
                   "Example expansion never replaces a pre-existing profile with the same ID")

        let groupID = "family"
        let before = try require(loaded.chats.first { $0.id == groupID })
        let additions = ["qiushui", "qiushui", "me", "not-a-contact", "changli"]
        try expect(DemoDirectory.addMembers(additions, to: groupID, in: &loaded), "A saved group accepts existing contacts")
        let after = try require(loaded.chats.first { $0.id == groupID })
        try expect(after.memberIDs == before.memberIDs + ["qiushui", "changli"],
                   "Adding members preserves order, ignores duplicates and rejects unknown IDs")
        try expect(after.title == before.title && after.avatarKey == before.avatarKey && loaded.messages[groupID]?.isEmpty == true,
                   "Changing membership does not reset a group's profile or history")
        try expect(!DemoDirectory.addMembers(additions, to: groupID, in: &loaded), "Adding the same members twice is a no-op")
        try expect(!DemoDirectory.addMembers(["qiushui"], to: "xixi", in: &loaded), "A private chat cannot become a group implicitly")

        loaded.chatListDisplayMode = .compact
        loaded.pinnedCollapsed = true
        loaded.compactAttachmentMenu = true
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("WeChatDirectoryTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try LocalArchiveFile(directory: root).save(loaded)
        let restored = try require(try LocalArchiveFile(directory: root).load()).archive
        try expect(restored.chatListDisplayMode == .compact && restored.pinnedCollapsed == true && restored.compactAttachmentMenu == true,
                   "Display mode, pin folding and attachment preference survive a fresh file load")
        try expect(restored.chats.first { $0.id == groupID }?.memberIDs == after.memberIDs,
                   "Added group members survive a fresh file load")
    }
}
