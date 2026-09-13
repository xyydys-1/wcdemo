import Foundation

extension LocalDataTests {
    static func migrationTests() throws {
        var old = DemoSeed.make()
        old.demoContentRevision = nil
        old.me.name = "我的名字"; old.me.avatarKey = "local:my-avatar.jpg"
        old.contacts[0].name = "我的备注"; old.contacts[0].avatarKey = "local:her-avatar.jpg"
        old.chats[0].title = "我的群名"; old.chats[0].avatarKey = "local:group-avatar.jpg"
        old.wallpapers["xixi"] = "local:background.jpg"; old.drafts["xixi"] = "待发送笔记"
        old.pinned = ["xixi"]; old.muted = ["family"]; old.hiddenChats = ["shore"]
        let example = DemoMessage(senderID: "xixi", incoming: true, kind: .photo("photo_avatar"))
        let exampleStack = DemoMessage(senderID: "me", incoming: false, kind: .photoStack(["photo_9", "photo_10", "photo_7"]))
        let ownText = DemoMessage(senderID: "me", incoming: false, kind: .text("这是我写的笔记，必须原样保留"))
        let ownPhoto = DemoMessage(senderID: "me", incoming: false, kind: .photo("local:own-photo.jpg"))
        let ownStack = DemoMessage(senderID: "me", incoming: false, kind: .photoStack(["local:one.jpg", "local:two.png"]))
        let incomingPhoto = DemoMessage(senderID: "xixi", incoming: true, kind: .photo("local:incoming.jpg"))
        let mixed = DemoMessage(senderID: "me", incoming: false,
                               kind: .photoStack(["local:first.jpg", "photo_9", "unknown-import.jpg", "local:last.jpg"]))
        old.messages["xixi"] = [example, exampleStack, ownText, ownPhoto, ownStack, incomingPhoto, mixed]
        old.messages["shore"] = []
        let onlyTimestamp = DemoMessage(senderID: nil, incoming: false, kind: .time("10:00"))
        old.messages["custom-empty"] = [onlyTimestamp]

        // The old JSON really has no migration key; decoding must remain compatible.
        let oldBytes = try JSONEncoder().encode(old)
        let json = try require(try JSONSerialization.jsonObject(with: oldBytes) as? [String: Any])
        try expect(json["demoContentRevision"] == nil, "Fixture represents the old archive format")
        var migrated = try JSONDecoder().decode(DemoArchive.self, from: oldBytes)
        try expect(DemoHistoryMigration.apply(to: &migrated), "First upgrade performs migration")
        let rows = try require(migrated.messages["xixi"])
        try expect(rows.map(\.id) == old.messages["xixi"]?.map(\.id), "Migration preserves message identity and ordering")
        try expect(rows[0].kind.photoKeys.isEmpty && !rows[0].kind.summary.isEmpty, "Example photo becomes actual text")
        try expect(rows[1].kind.photoKeys.isEmpty && !rows[1].kind.summary.isEmpty, "Example stack becomes actual text")
        let messageEncoder = JSONEncoder()
        messageEncoder.outputFormatting = [.sortedKeys]
        for index in 2...5 {
            try expect(try messageEncoder.encode(rows[index]) == messageEncoder.encode(old.messages["xixi"]![index]),
                       "Own text, single photos, stacks and incoming local photos are preserved")
        }
        try expect(rows[6].kind.photoKeys == ["local:first.jpg", "unknown-import.jpg", "local:last.jpg"],
                   "Mixed media keeps every non-example key in its original order")
        try expect(migrated.messages["shore"]?.isEmpty == true, "Cleared history is never regenerated")
        try expect(migrated.messages["custom-empty"]?.first?.id == onlyTimestamp.id,
                   "Unrelated timestamp-only conversations are untouched")

        var metadata = migrated
        metadata.messages = old.messages; metadata.demoContentRevision = nil
        try expect(try canonical(metadata) == canonical(old), "All profile, avatar, wallpaper and draft metadata is unchanged")
        let afterFirstPass = try canonical(migrated)
        try expect(!DemoHistoryMigration.apply(to: &migrated), "Migration is idempotent")
        try expect(try canonical(migrated) == afterFirstPass, "Repeated launches do not mutate history")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WeChatMigration-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = LocalArchiveFile(directory: directory)
        try file.save(old); try file.save(migrated)
        var reopened = try require(try LocalArchiveFile(directory: directory).load()).archive
        try expect(!DemoHistoryMigration.apply(to: &reopened), "Migration revision is durable after a fresh disk load")
        try expect(reopened.messages["xixi"]?.map(\.id) == rows.map(\.id), "Migrated history survives restart")
    }

}
