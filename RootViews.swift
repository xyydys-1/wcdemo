import SwiftUI
import UIKit

@objc(WeChatDemoRootFactory)
public final class WeChatDemoRootFactory: NSObject {
    @objc public static func makeRootViewController() -> UIViewController {
        guard #available(iOS 26.0, *) else { return UIViewController() }
        let controller = UIHostingController(rootView: WeChatDemoRoot()); controller.view.backgroundColor = .systemBackground; return controller
    }
}

@available(iOS 26.0, *) private enum RootTab: Hashable { case chats, contacts, discover, me, search }

@available(iOS 26.0, *)
struct WeChatDemoRoot: View {
    @StateObject private var store = DemoStore()
    @State private var selectedTab: RootTab = .chats
    @State private var searchText = ""
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("微信", systemImage: "message.fill", value: RootTab.chats) { ChatsView() }
            Tab("通讯录", systemImage: "person.2.fill", value: RootTab.contacts) { ContactsView() }
            Tab("发现", systemImage: "safari.fill", value: RootTab.discover) { DiscoverView() }
            Tab("我", systemImage: "person.fill", value: RootTab.me) { MeView() }
            Tab(value: RootTab.search, role: .search) { SearchHubView(query: $searchText) }
        }
        .searchable(text: $searchText, prompt: "搜索").tabViewSearchActivation(.searchTabSelection).tabBarMinimizeBehavior(.onScrollDown).tint(Color.wxGreen).environmentObject(store)
    }
}

@available(iOS 26.0, *) private enum QuickRoute: String, Identifiable, Hashable { case newGroup, addFriend, payment; var id: String { rawValue } }

@available(iOS 26.0, *)
struct ChatsView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var quickRoute: QuickRoute?
    @State private var deleteCandidate: DemoChat?
    private var compact: Bool { store.chatListDisplayMode == .compact }
    private var pinnedChats: [DemoChat] { store.chats.filter { store.pinned.contains($0.id) } }
    private var normalChats: [DemoChat] { store.chats.filter { !store.pinned.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Group {
                if compact { chatList.listStyle(.plain).listSectionSpacing(0) }
                else { chatList.listStyle(.insetGrouped) }
            }
            .navigationTitle("微信")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("发起群聊", systemImage: "bubble.left.and.bubble.right.fill") { quickRoute = .newGroup }
                        Button("添加朋友", systemImage: "person.badge.plus") { quickRoute = .addFriend }
                        Button("扫一扫", systemImage: "qrcode.viewfinder") { }
                        Button("收付款", systemImage: "qrcode") { quickRoute = .payment }
                        Menu("显示模式", systemImage: "list.bullet") {
                            Picker("显示模式", selection: Binding(get: { store.chatListDisplayMode }, set: { store.setDisplayMode($0) })) {
                                Text("紧凑").tag(ChatListDisplayMode.compact); Text("默认").tag(ChatListDisplayMode.standard)
                            }
                        }
                    } label: { Image(systemName: "plus").foregroundStyle(.primary) }.tint(.primary)
                }
            }
            .navigationDestination(item: $quickRoute) { route in
                switch route { case .newGroup: CreateGroupView(); case .addFriend: NewContactView(); case .payment: PaymentView() }
            }
            .alert("删除该聊天？", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
                Button("删除", role: .destructive) { if let c = deleteCandidate { store.deleteChat(c.id) }; deleteCandidate = nil }; Button("取消", role: .cancel) { deleteCandidate = nil }
            }
        }
    }

    private var chatList: some View {
        List {
            if !pinnedChats.isEmpty {
                Section {
                    if !store.pinnedCollapsed { ForEach(pinnedChats) { chat in chatLink(chat, pinned: true) } }
                } header: {
                    HStack { Text("置顶"); Spacer(); Button { store.setPinnedCollapsed(!store.pinnedCollapsed) } label: { Image(systemName: store.pinnedCollapsed ? "chevron.down.circle" : "chevron.up.circle") }.buttonStyle(.plain) }
                }
            }
            Section { ForEach(normalChats) { chat in chatLink(chat, pinned: false) } }
        }
    }

    @ViewBuilder private func chatLink(_ chat: DemoChat, pinned: Bool) -> some View {
        NavigationLink { ChatView(chatID: chat.id) } label: { ChatRow(chat: chat, compact: compact) }
            .swipeActions(edge: .leading, allowsFullSwipe: false) { Button { store.setPinned(!store.pinned.contains(chat.id), for: chat.id) } label: { Label(store.pinned.contains(chat.id) ? "取消置顶" : "置顶", systemImage: "pin.fill") }.tint(.orange) }
            .swipeActions(edge: .trailing) { Button(role: .destructive) { deleteCandidate = chat } label: { Label("删除", systemImage: "trash.fill") } }
    }
}

@available(iOS 26.0, *)
private struct ChatRow: View {
    let chat: DemoChat; let compact: Bool
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                ChatAvatar(chat: chat, size: compact ? 44 : 52)
                if chat.unread > 0 {
                    Text("\(chat.unread)").font(.caption2.bold()).foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18).background(.red, in: Circle()).offset(x: 6, y: -6)
                }
            }
            VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                HStack { Text(chat.title).font(.system(size: compact ? 16 : 17, weight: .semibold)); Spacer(); Text(chat.time).font(.caption).foregroundStyle(.tertiary) }
                Text(chat.subtitle).font(compact ? .caption : .subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, compact ? 0 : 4)
        .alignmentGuide(.listRowSeparatorLeading) { _ in (compact ? 44 : 52) + 12 }
    }
}

@available(iOS 26.0, *)
struct SearchHubView: View {
    @EnvironmentObject private var store: DemoStore
    @Binding var query: String
    private var filtered: [DemoChat] { query.isEmpty ? store.chats : store.chats.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) } }
    var body: some View { NavigationStack { List(filtered) { chat in NavigationLink { ChatView(chatID: chat.id) } label: { HStack { ChatAvatar(chat: chat, size: 42); VStack(alignment: .leading) { Text(chat.title); Text(chat.subtitle).font(.caption).foregroundStyle(.secondary) } } } }.navigationTitle("搜索") } }
}
