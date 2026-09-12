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
            DemoChat(id: "xixi", title: "汐汐", subtitle: "图片", time: "17:15", unread: 0, avatarSymbol: "sparkles", avatarColor: .pink),
            DemoChat(id: "jinzhou", title: "今州小分队", subtitle: "秋水: 收到", time: "14:00", unread: 0, avatarSymbol: "person.2.fill", avatarColor: .green, isGroup: true),
            DemoChat(id: "qiuqiu", title: "七丘行动-残星会", subtitle: "会议时间改到晚上", time: "22:03", unread: 0, avatarSymbol: "star.circle.fill", avatarColor: .red, isGroup: true),
            DemoChat(id: "xiaoka", title: "小卡", subtitle: "好耶！", time: "17:08", unread: 1, avatarSymbol: "heart.fill", avatarColor: .purple),
            DemoChat(id: "jiazhu", title: "家主", subtitle: "这周末一起去看看吧", time: "17:07", unread: 1, avatarSymbol: "crown.fill", avatarColor: .blue),
            DemoChat(id: "qiushui", title: "秋水", subtitle: "嗯", time: "16:56", unread: 0, avatarSymbol: "leaf.fill", avatarColor: .teal)
        ]

        var messages: [String: [DemoMessage]] = [:]
        messages["xixi"] = [
            DemoMessage(senderID: nil, incoming: false, kind: .time("17:11")),
            DemoMessage(senderID: "xixi", incoming: true, kind: .photo("photo_avatar")),
            DemoMessage(senderID: nil, incoming: false, kind: .time("17:12")),
            DemoMessage(senderID: "me", incoming: false, kind: .photoStack(["photo_7", "photo_9", "photo_8", "photo_6"])),
            DemoMessage(senderID: "me", incoming: false, kind: .text("怎么样？")),
            DemoMessage(senderID: nil, incoming: false, kind: .time("17:15")),
            DemoMessage(senderID: "xixi", incoming: true, kind: .photo("photo_chibi"))
        ]

        messages["shore"] = [
            DemoMessage(senderID: nil, incoming: false, kind: .time("2026年6月29日 12:00")),
            DemoMessage(senderID: "shore", incoming: true, kind: .text("欢迎回家！")),
            DemoMessage(senderID: "shore", incoming: true, kind: .photo("photo_avatar")),
            DemoMessage(senderID: "me", incoming: false, kind: .photoStack(["photo_12", "photo_10", "photo_8"])),
            DemoMessage(senderID: nil, incoming: false, kind: .time("22:10"))
        ]

        messages["blackshore"] = [
            DemoMessage(senderID: nil, incoming: false, kind: .time("22:09")),
            DemoMessage(senderID: "xixi", incoming: true, kind: .text("今晚继续行动吗？")),
            DemoMessage(senderID: "me", incoming: false, kind: .text("可以")),
            DemoMessage(senderID: "shore", incoming: true, kind: .photo("photo_12"))
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
        // Sample thumbnails are square crops, so their presentation uses reference aspect hints.
        messages["xixi"]?[3].kind = .photoStack(["photo_9", "photo_10", "photo_11", "photo_12", "photo_8", "photo_7"])
        var archive = DemoArchive()
        archive.chats = chats; archive.contacts = contacts; archive.messages = messages
        return archive
    }
}
