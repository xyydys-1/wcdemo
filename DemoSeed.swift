import Foundation

enum DemoSeed {
    static func make() -> DemoArchive {
        var contacts = [
            DemoContact(id: "xixi", name: "汐汐", symbol: "sparkles", color: .pink, subtitle: "晚点一起玩"),
            DemoContact(id: "shore", name: "岸宝", symbol: "moon.stars.fill", color: .blue, subtitle: "欢迎回家！"),
            DemoContact(id: "heihai", name: "黑海岸", symbol: "water.waves", color: .indigo),
            DemoContact(id: "qiushui", name: "秋水", symbol: "leaf.fill", color: .teal),
            DemoContact(id: "changli", name: "长离", symbol: "flame.fill", color: .orange),
            DemoContact(id: "cartethyia", name: "卡提希娅", symbol: "star.fill", color: .purple),
            DemoContact(id: "shorekeeper", name: "ShoreKeeper", symbol: "sparkle", color: .cyan)
        ]

        var chats = [
            DemoChat(id: "blackshore", title: "黑海岸小分队", subtitle: "岸宝: 今晚继续行动", time: "17:18", unread: 2, avatarSymbol: "person.3.fill", avatarColor: .indigo, isGroup: true),
            DemoChat(id: "family", title: "相亲相爱一家人", subtitle: "妈妈: 记得早点休息", time: "17:17", unread: 1, avatarSymbol: "house.fill", avatarColor: .orange, isGroup: true),
            DemoChat(id: "xixi", title: "汐汐", subtitle: "好呀，晚点见！", time: "17:15", unread: 0, avatarSymbol: "sparkles", avatarColor: .pink),
            DemoChat(id: "jinzhou", title: "今州小分队", subtitle: "秋水: 收到", time: "14:00", unread: 0, avatarSymbol: "person.2.fill", avatarColor: .green, isGroup: true),
            DemoChat(id: "qiuqiu", title: "七丘行动-残星会", subtitle: "会议时间改到晚上", time: "22:03", unread: 0, avatarSymbol: "star.circle.fill", avatarColor: .red, isGroup: true),
            DemoChat(id: "xiaoka", title: "小卡", subtitle: "好耶！", time: "17:08", unread: 1, avatarSymbol: "heart.fill", avatarColor: .purple),
            DemoChat(id: "jiazhu", title: "家主", subtitle: "这周末一起去看看吧", time: "17:07", unread: 1, avatarSymbol: "crown.fill", avatarColor: .blue),
            DemoChat(id: "qiushui", title: "秋水", subtitle: "嗯", time: "16:56", unread: 0, avatarSymbol: "leaf.fill", avatarColor: .teal)
        ]

        var messages: [String: [DemoMessage]] = [:]
        messages["xixi"] = [
            DemoMessage(senderID: nil, incoming: false, kind: .time("17:11")),
            DemoMessage(senderID: "xixi", incoming: true, kind: .text("今天想去哪里逛逛？")),
            DemoMessage(senderID: nil, incoming: false, kind: .time("17:12")),
            DemoMessage(senderID: "me", incoming: false, kind: .text("一起去海边走走吧。")),
            DemoMessage(senderID: "me", incoming: false, kind: .text("怎么样？")),
            DemoMessage(senderID: nil, incoming: false, kind: .time("17:15")),
            DemoMessage(senderID: "xixi", incoming: true, kind: .text("好呀，晚点见！"))
        ]

        messages["shore"] = [
            DemoMessage(senderID: nil, incoming: false, kind: .time("2026年6月29日 12:00")),
            DemoMessage(senderID: "shore", incoming: true, kind: .text("欢迎回家！")),
            DemoMessage(senderID: "shore", incoming: true, kind: .text("今天过得怎么样？")),
            DemoMessage(senderID: "me", incoming: false, kind: .text("一切顺利，晚点聊。"))
        ]

        messages["blackshore"] = [
            DemoMessage(senderID: nil, incoming: false, kind: .time("22:09")),
            DemoMessage(senderID: "xixi", incoming: true, kind: .text("今晚继续行动吗？")),
            DemoMessage(senderID: "me", incoming: false, kind: .text("可以")),
            DemoMessage(senderID: "shore", incoming: true, kind: .text("那我们晚点集合。"))
        ]

        messages["family"] = [
            DemoMessage(senderID: nil, incoming: false, kind: .time("21:48")),
            DemoMessage(senderID: "xixi", incoming: true, kind: .text("今晚一起吃饭吗？")),
            DemoMessage(senderID: "shore", incoming: true, kind: .text("记得早点休息～")),
            DemoMessage(senderID: "me", incoming: false, kind: .text("好，晚点见"))
        ]
        contacts += [
            DemoContact(id: "xiaoka", name: "小卡", symbol: "heart.fill", color: .purple),
            DemoContact(id: "jiazhu", name: "家主", symbol: "crown.fill", color: .blue)
        ]
        let members: [String: [String]] = [
            "blackshore": ["me", "xixi", "shore", "heihai"],
            "family": ["me", "xixi", "shore"],
            "jinzhou": ["me", "qiushui", "changli"],
            "qiuqiu": ["me", "cartethyia", "shorekeeper"]
        ]
        for index in chats.indices {
            chats[index].memberIDs = members[chats[index].id] ?? []
        }
        // Every seeded list preview has an actual message behind it. Never run on reload.
        for chat in chats where messages[chat.id] == nil {
            let sender = chat.isGroup ? (chat.memberIDs.first { $0 != "me" } ?? "xixi") : chat.id
            let text = chat.subtitle.components(separatedBy: ": ").last ?? chat.subtitle
            messages[chat.id] = [
                DemoMessage(senderID: nil, incoming: false, kind: .time(chat.time)),
                DemoMessage(senderID: sender, incoming: true, kind: .text(text))
            ]
        }
        var archive = DemoArchive()
        archive.demoContentRevision = DemoHistoryMigration.currentRevision
        archive.chats = chats; archive.contacts = contacts; archive.messages = messages
        return archive
    }
}

enum DemoHistoryMigration {
    static let currentRevision = 1
    private static let sampleKeys = Set((1...15).map { "photo_\($0)" } + ["photo_avatar", "photo_chibi"])

    // Rewrite only the old bundled examples, in place. Local imports, message IDs,
    // names, avatars, settings, cleared conversations and user text remain intact.
    @discardableResult
    static func apply(to archive: inout DemoArchive) -> Bool {
        guard (archive.demoContentRevision ?? 0) < currentRevision else { return false }
        for chatID in Array(archive.messages.keys) {
            guard var messages = archive.messages[chatID] else { continue }
            var replacedExample = false
            for index in messages.indices {
                let keys = messages[index].kind.photoKeys
                guard keys.contains(where: sampleKeys.contains) else { continue }
                replacedExample = true
                let retained = keys.filter { !sampleKeys.contains($0) }
                if retained.count == 1 { messages[index].kind = .photo(retained[0]) }
                else if !retained.isEmpty { messages[index].kind = .photoStack(retained) }
                else { messages[index].kind = .text(replacement(chatID, message: messages[index], keys: keys)) }
            }
            // An old example ended in a timestamp with no following message.
            if replacedExample {
                while let last = messages.last, case .time = last.kind { messages.removeLast() }
            }
            archive.messages[chatID] = messages
        }
        archive.demoContentRevision = currentRevision
        return true
    }

    private static func replacement(_ chatID: String, message: DemoMessage, keys: [String]) -> String {
        switch chatID {
        case "xixi":
            if !message.incoming { return "一起去海边走走吧。" }
            return keys.contains("photo_chibi") ? "好呀，晚点见！" : "今天想去哪里逛逛？"
        case "shore": return message.incoming ? "今天过得怎么样？" : "一切顺利，晚点聊。"
        case "blackshore": return "那我们晚点集合。"
        default: return message.incoming ? "晚点见！" : "好，晚点聊。"
        }
    }
}
