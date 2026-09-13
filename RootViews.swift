import SwiftUI
import UIKit

@MainActor
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
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.flush() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in store.flush() }
        .alert("本地记录", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("好", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

@available(iOS 26.0, *)
private enum QuickRoute: String, Identifiable, Hashable {
    case newGroup, addFriend, payment
    var id: String { rawValue }
}

@available(iOS 26.0, *)
private enum ChatRoute: Hashable {
    case chat(String)
    case quick(QuickRoute)
}

@available(iOS 26.0, *)
struct ChatsView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var path: [ChatRoute] = []
    @State private var deleteCandidate: DemoChat?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !store.pinned.isEmpty {
                    Section("置顶") {
                        ForEach(store.chats.filter { store.pinned.contains($0.id) && !store.state.hiddenChats.contains($0.id) }) { chat in
                            chatLink(chat)
                        }
                    }
                }

                Section {
                    ForEach(store.chats.filter { !store.pinned.contains($0.id) && !store.state.hiddenChats.contains($0.id) }) { chat in
                        chatLink(chat)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("微信")
            .toolbar {
                // Keep the root item alive throughout interactive push/pop. NavigationStack
                // chooses each page's toolbar and animates its native glass background.
                ToolbarItem(id: "chats.add", placement: .topBarTrailing) {
                    Menu {
                        Button("发起群聊", systemImage: "bubble.left.and.bubble.right.fill") { path.append(.quick(.newGroup)) }
                        Button("添加朋友", systemImage: "person.badge.plus") { path.append(.quick(.addFriend)) }
                        Button("扫一扫", systemImage: "qrcode.viewfinder") { }
                        Button("收付款", systemImage: "qrcode") { path.append(.quick(.payment)) }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.primary)
                            .frame(width: 24, height: 24)
                    }
                    .tint(Color.primary)
                }
            }
            .navigationDestination(for: ChatRoute.self) { route in
                switch route {
                case .chat(let id): ChatView(chatID: id)
                case .quick(.newGroup): CreateGroupView()
                case .quick(.addFriend): AddFriendView()
                case .quick(.payment): PaymentView()
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
                Text("将删除这段会话的本地消息，重新打开后也不会恢复。")
            }
        }
    }

    @ViewBuilder
    private func chatLink(_ chat: DemoChat) -> some View {
        NavigationLink(value: ChatRoute.chat(chat.id)) {
            ChatRow(chat: chat)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                store.setPinned(!store.pinned.contains(chat.id), for: chat.id)
            } label: {
                Label(store.pinned.contains(chat.id) ? "取消置顶" : "置顶", systemImage: "pin.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleteCandidate = chat } label: {
                Label("删除", systemImage: "trash.fill")
            }
            Button { store.hideChat(chat.id) } label: {
                Label("不显示", systemImage: "eye.slash.fill")
            }
            .tint(.gray)
        }
    }
}

@available(iOS 26.0, *)
private struct ChatRow: View {
    @EnvironmentObject private var store: DemoStore
    let chat: DemoChat

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                ProfileAvatar(id: chat.id, size: 52)
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
                Text(store.preview(for: chat))
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
        return store.chats.filter { $0.title.localizedCaseInsensitiveContains(query) || store.preview(for: $0).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section("最近搜索") {
                        ForEach(store.chats.prefix(5)) { chat in
                            NavigationLink { ChatView(chatID: chat.id) } label: {
                                Label(chat.title, systemImage: "clock")
                            }
                        }
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
