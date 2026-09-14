import Foundation

enum DemoSeed {
    static func make() -> DemoArchive {
        let contacts = [
            DemoContact(id: "xixi", name: "汐汐", symbol: "sparkles", colorName: "pink", subtitle: "晚点一起玩"),
            DemoContact(id: "shore", name: "岸宝", symbol: "moon.stars.fill", colorName: "blue", subtitle: "欢迎回家！"),
            DemoContact(id: "heihai", name: "黑海岸", symbol: "water.waves", colorName: "indigo"),
            DemoContact(id: "qiushui", name: "秋水", symbol: "leaf.fill", colorName: "teal"),
            DemoContact(id: "changli", name: "长离", symbol: "flame.fill", colorName: "orange"),
            DemoContact(id: "cartethyia", name: "卡提希娅", symbol: "star.fill", colorName: "purple"),
            DemoContact(id: "shorekeeper", name: "ShoreKeeper", symbol: "sparkle", colorName: "cyan"),
            DemoContact(id: "xiaoka", name: "小卡", symbol: "heart.fill", colorName: "purple"),
            DemoContact(id: "jiazhu", name: "家主", symbol: "crown.fill", colorName: "blue"),
            DemoContact(id: "dasha", name: "大傻椿", symbol: "circle.fill", colorName: "gray"),
            DemoContact(id: "yangyang", name: "咩", symbol: "cloud.fill", colorName: "pink"),
            DemoContact(id: "rover", name: "漂泊者", symbol: "person.crop.circle.fill", colorName: "blue")
        ]
        let chats = [
            DemoChat(id: "blackshore", title: "黑海岸小分队", subtitle: "岸宝: 今晚继续行动", time: "17:18", unread: 2, avatarSymbol: "person.3.fill", avatarColorName: "indigo", isGroup: true, memberIDs: ["me","xixi","shore","heihai"]),
            DemoChat(id: "family", title: "相亲相爱一家人", subtitle: "妈妈: 记得早点休息", time: "17:17", unread: 1, avatarSymbol: "house.fill", avatarColorName: "orange", isGroup: true, memberIDs: ["me","xixi","shore"]),
            DemoChat(id: "xixi", title: "汐汐", subtitle: "收到", time: "17:15", unread: 0, avatarSymbol: "sparkles", avatarColorName: "pink"),
            DemoChat(id: "jinzhou", title: "今州小分队", subtitle: "秋水: 收到", time: "14:00", unread: 0, avatarSymbol: "person.2.fill", avatarColorName: "green", isGroup: true, memberIDs: ["me","qiushui","changli"]),
            DemoChat(id: "qiuqiu", title: "七丘行动-残星会", subtitle: "会议时间改到晚上", time: "22:03", unread: 0, avatarSymbol: "star.circle.fill", avatarColorName: "red", isGroup: true, memberIDs: ["me","cartethyia","shorekeeper"]),
            DemoChat(id: "xiaoka", title: "小卡", subtitle: "好耶！", time: "17:08", unread: 1, avatarSymbol: "heart.fill", avatarColorName: "purple"),
            DemoChat(id: "jiazhu", title: "家主", subtitle: "这周末一起去看看吧", time: "17:07", unread: 1, avatarSymbol: "crown.fill", avatarColorName: "blue"),
            DemoChat(id: "qiushui", title: "秋水", subtitle: "嗯", time: "16:56", unread: 0, avatarSymbol: "leaf.fill", avatarColorName: "teal")
        ]
        var messages: [String: [DemoMessage]] = [:]
        for chat in chats {
            let text = chat.subtitle.components(separatedBy: ": ").last ?? chat.subtitle
            messages[chat.id] = [
                DemoMessage(senderID: nil, incoming: false, kind: .time(chat.time)),
                DemoMessage(senderID: chat.isGroup ? (chat.memberIDs.first { $0 != "me" } ?? "xixi") : chat.id,
                            incoming: true, kind: .text(text))
            ]
        }
        var archive = DemoArchive(chats: chats, contacts: contacts, messages: messages)
        archive.pinned = ["blackshore", "family"]
        return archive
    }
}
