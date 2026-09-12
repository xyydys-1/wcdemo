import SwiftUI
import UIKit

@objc(WeChatDemoRootFactory)
public final class WeChatDemoRootFactory: NSObject {
    @objc public static func makeRootViewController() -> UIViewController {
        guard #available(iOS 26.0, *) else { return UIViewController() }
        let controller = UIHostingController(rootView: WeChatDemoRoot())
        controller.view.backgroundColor = .systemBackground
        return controller
    }
}

@available(iOS 26.0, *)
private enum RootTab: Hashable {
    case chats, contacts, discover, me, search
}

@available(iOS 26.0, *)
struct WeChatDemoRoot: View {
    @StateObject private var store = DemoStore()
    @State private var selectedTab: RootTab = .chats
    @State private var searchText = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("微信", systemImage: "message.fill", value: RootTab.chats) {
                ChatsView()
            }
            Tab("通讯录", systemImage: "person.2.fill", value: RootTab.contacts) {
                ContactsView()
            }
            Tab("发现", systemImage: "safari.fill", value: RootTab.discover) {
                DiscoverView()
            }
            Tab("我", systemImage: "person.fill", value: RootTab.me) {
                MeView()
            }
            Tab(value: RootTab.search, role: .search) {
                SearchHubView(query: $searchText)
            }
        }
        .searchable(text: $searchText, prompt: "搜索")
        .tabViewSearchActivation(.searchTabSelection)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.wxGreen)
        .environmentObject(store)
    }
}

@available(iOS 26.0, *)
private enum QuickRoute: String, Identifiable, Hashable {
    case newGroup, addFriend, payment
    var id: String { rawValue }
}

@available(iOS 26.0, *)
struct ChatsView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var quickRoute: QuickRoute?
    @State private var deleteCandidate: DemoChat?

    var body: some View {
        NavigationStack {
            List {
                if !store.pinned.isEmpty {
                    Section("置顶") {
                        ForEach(store.chats.filter { store.pinned.contains($0.id) }) { chat in
                            chatLink(chat)
                        }
                    }
                }

                Section {
                    ForEach(store.chats.filter { !store.pinned.contains($0.id) }) { chat in
                        chatLink(chat)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("微信")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("发起群聊", systemImage: "bubble.left.and.bubble.right.fill") { quickRoute = .newGroup }
                        Button("添加朋友", systemImage: "person.badge.plus") { quickRoute = .addFriend }
                        Button("扫一扫", systemImage: "qrcode.viewfinder") { }
                        Button("收付款", systemImage: "qrcode") { quickRoute = .payment }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.primary)
                    }
                    .tint(Color.primary)
                }
            }
            .navigationDestination(item: $quickRoute) { route in
                switch route {
                case .newGroup: CreateGroupView()
                case .addFriend: AddFriendView()
                case .payment: PaymentView()
                }
            }
            .alert("删除该聊天？", isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let chat = deleteCandidate { store.deleteChat(chat.id) }
                    deleteCandidate = nil
                }
                Button("取消", role: .cancel) { deleteCandidate = nil }
            } message: {
                Text("删除后将清除当前演示中的会话记录。")
            }
        }
    }

    @ViewBuilder
    private func chatLink(_ chat: DemoChat) -> some View {
        NavigationLink {
            ChatView(chatID: chat.id)
        } label: {
            ChatRow(chat: chat)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                if store.pinned.contains(chat.id) { store.pinned.remove(chat.id) }
                else { store.pinned.insert(chat.id) }
            } label: {
                Label(store.pinned.contains(chat.id) ? "取消置顶" : "置顶", systemImage: "pin.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleteCandidate = chat } label: {
                Label("删除", systemImage: "trash.fill")
            }
            Button { } label: {
                Label("不显示", systemImage: "eye.slash.fill")
            }
            .tint(.gray)
        }
    }
}

@available(iOS 26.0, *)
private struct ChatRow: View {
    let chat: DemoChat

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                DemoAvatar(symbol: chat.avatarSymbol, color: chat.avatarColor, size: 52)
                if chat.unread > 0 {
                    Text("\(chat.unread)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(.red, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(chat.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(chat.time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(chat.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 26.0, *)
struct SearchHubView: View {
    @EnvironmentObject private var store: DemoStore
    @Binding var query: String

    var filteredChats: [DemoChat] {
        guard !query.isEmpty else { return store.chats }
        return store.chats.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section("最近搜索") {
                        Label("汐汐", systemImage: "clock")
                        Label("黑海岸小分队", systemImage: "clock")
                    }
                } else {
                    Section("聊天") {
                        ForEach(filteredChats) { chat in
                            NavigationLink(chat.title) { ChatView(chatID: chat.id) }
                        }
                    }
                }
            }
            .navigationTitle("搜索")
        }
    }
}
