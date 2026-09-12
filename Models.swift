import SwiftUI
import Combine
import UIKit

struct DemoContact: Identifiable {
    let id: String
    var name: String
    var symbol: String
    var color: Color
    var subtitle: String = ""
}

enum DemoMessageKind {
    case text(String)
    case photo(String)
    case photoStack([String])
    case time(String)
}

struct DemoMessage: Identifiable {
    let id = UUID()
    var senderID: String?
    var incoming: Bool
    var kind: DemoMessageKind
}

struct DemoChat: Identifiable {
    let id: String
    var title: String
    var subtitle: String
    var time: String
    var unread: Int
    var avatarSymbol: String
    var avatarColor: Color
    var isGroup: Bool = false
}

final class DemoStore: ObservableObject {
    @Published var chats: [DemoChat] = []
    @Published var contacts: [DemoContact] = []
    @Published var messages: [String: [DemoMessage]] = [:]
    @Published var pinned: Set<String> = []
    @Published var muted: Set<String> = []
    @Published var chatWallpapers: [String: UIImage] = [:]

    init() {
        contacts = [
            DemoContact(id: "xixi", name: "汐汐", symbol: "sparkles", color: .pink, subtitle: "晚点一起玩"),
            DemoContact(id: "shore", name: "岸宝", symbol: "moon.stars.fill", color: .blue, subtitle: "欢迎回家！"),
            DemoContact(id: "heihai", name: "黑海岸", symbol: "water.waves", color: .indigo),
            DemoContact(id: "qiushui", name: "秋水", symbol: "leaf.fill", color: .teal),
            DemoContact(id: "changli", name: "长离", symbol: "flame.fill", color: .orange),
            DemoContact(id: "cartethyia", name: "卡提希娅", symbol: "star.fill", color: .purple),
            DemoContact(id: "shorekeeper", name: "ShoreKeeper", symbol: "sparkle", color: .cyan)
        ]

        chats = [
            DemoChat(id: "blackshore", title: "黑海岸小分队", subtitle: "岸宝: 今晚继续行动", time: "17:18", unread: 2, avatarSymbol: "person.3.fill", avatarColor: .indigo, isGroup: true),
            DemoChat(id: "family", title: "相亲相爱一家人", subtitle: "妈妈: 记得早点休息", time: "17:17", unread: 1, avatarSymbol: "house.fill", avatarColor: .orange, isGroup: true),
            DemoChat(id: "xixi", title: "汐汐", subtitle: "图片", time: "17:15", unread: 0, avatarSymbol: "sparkles", avatarColor: .pink),
            DemoChat(id: "jinzhou", title: "今州小分队", subtitle: "秋水: 收到", time: "14:00", unread: 0, avatarSymbol: "person.2.fill", avatarColor: .green, isGroup: true),
            DemoChat(id: "qiuqiu", title: "七丘行动-残星会", subtitle: "会议时间改到晚上", time: "22:03", unread: 0, avatarSymbol: "star.circle.fill", avatarColor: .red, isGroup: true),
            DemoChat(id: "xiaoka", title: "小卡", subtitle: "好耶！", time: "17:08", unread: 1, avatarSymbol: "heart.fill", avatarColor: .purple),
            DemoChat(id: "jiazhu", title: "家主", subtitle: "这周末一起去看看吧", time: "17:07", unread: 1, avatarSymbol: "crown.fill", avatarColor: .blue),
            DemoChat(id: "qiushui", title: "秋水", subtitle: "嗯", time: "16:56", unread: 0, avatarSymbol: "leaf.fill", avatarColor: .teal)
        ]

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
    }

    func chat(_ id: String) -> DemoChat {
        if let found = chats.first(where: { $0.id == id }) { return found }
        return DemoChat(id: id, title: "聊天", subtitle: "", time: "", unread: 0, avatarSymbol: "person.fill", avatarColor: .gray)
    }

    func contact(_ id: String) -> DemoContact? {
        contacts.first(where: { $0.id == id })
    }

    func sendText(_ text: String, to chatID: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages[chatID, default: []].append(DemoMessage(senderID: "me", incoming: false, kind: .text(trimmed)))
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].subtitle = trimmed
            chats[index].time = "刚刚"
        }
    }

    func sendPhotos(_ names: [String], to chatID: String) {
        guard !names.isEmpty else { return }
        messages[chatID, default: []].append(DemoMessage(senderID: "me", incoming: false, kind: .photoStack(names)))
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].subtitle = "[图片]"
            chats[index].time = "刚刚"
        }
    }

    func deleteChat(_ id: String) {
        chats.removeAll { $0.id == id }
    }

    func deleteContact(_ id: String) {
        contacts.removeAll { $0.id == id }
    }

    func createGroup(memberIDs: [String]) -> String {
        let id = "newgroup"
        if !chats.contains(where: { $0.id == id }) {
            chats.insert(
                DemoChat(id: id, title: "群聊", subtitle: "你已创建群聊", time: "刚刚", unread: 0, avatarSymbol: "person.3.sequence.fill", avatarColor: .green, isGroup: true),
                at: 0
            )
            messages[id] = [DemoMessage(senderID: nil, incoming: false, kind: .time("你已创建群聊"))]
        }
        return id
    }
}

struct DemoAvatar: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(color.gradient)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

extension Color {
    static let wxGreen = Color(red: 0.09, green: 0.78, blue: 0.34)
    static let wxBubbleGreen = Color(red: 0.58, green: 0.94, blue: 0.47)
}
