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
    @StateObject private var nativeAudit = WCNativeBarAudit()

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
        .environmentObject(nativeAudit)
        .background { WCNativeBarAuditAttachment(audit: nativeAudit).frame(width: 0, height: 0) }
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.flush() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in store.flush(); nativeAudit.stop() }
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
    @EnvironmentObject private var nativeAudit: WCNativeBarAudit
    @State private var path: [ChatRoute] = []
    @State private var deleteCandidate: DemoChat?
    @AppStorage("wechat26.homeDisplayMode") private var homeDisplayMode = "default"
    @AppStorage("wechat26.pinnedCollapsed") private var pinnedCollapsed = false

    private var isCompact: Bool { homeDisplayMode == "compact" }
    private var pinnedChats: [DemoChat] {
        store.chats.filter { store.pinned.contains($0.id) && !store.state.hiddenChats.contains($0.id) }
    }
    private var normalChats: [DemoChat] {
        store.chats.filter { !store.pinned.contains($0.id) && !store.state.hiddenChats.contains($0.id) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            chatList
                .navigationTitle("微信")
                .toolbar {
                    // Keep the root item alive throughout interactive push/pop. NavigationStack
                    // chooses each page's toolbar and animates its native glass background.
                    ToolbarItem(id: "chats.add", placement: .topBarTrailing) {
                        Menu {
                            Button("发起群聊", systemImage: "bubble.left.and.bubble.right.fill") { path.append(.quick(.newGroup)) }
                            Button("添加朋友", systemImage: "person.badge.plus") { path.append(.quick(.addFriend)) }
                            Divider()
                            Menu {
                                Text(nativeAudit.status)
                                Button("开始 8 秒原生采样", systemImage: "record.circle") { nativeAudit.start() }
                                Button("分享诊断文件", systemImage: "square.and.arrow.up") { nativeAudit.shareReport() }
                                Button("复制诊断", systemImage: "doc.on.doc") { nativeAudit.copyReport() }
                            } label: {
                                Label("原生底栏诊断 AUDIT2", systemImage: "waveform.path.ecg")
                            }
                            Divider()
                            Button("扫一扫", systemImage: "qrcode.viewfinder") { }
                            Button("收付款", systemImage: "qrcode") { path.append(.quick(.payment)) }
                            Menu {
                                Button { homeDisplayMode = "compact" } label: {
                                    if isCompact { Label("紧凑", systemImage: "checkmark") }
                                    else { Text("紧凑") }
                                }
                                Button { homeDisplayMode = "default" } label: {
                                    if !isCompact { Label("默认", systemImage: "checkmark") }
                                    else { Text("默认") }
                                }
                            } label: {
                                Label("显示模式", systemImage: "list.bullet")
                            }
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
        .alert("原生底栏诊断", isPresented: Binding(
            get: { nativeAudit.notice != nil },
            set: { if !$0 { nativeAudit.notice = nil } }
        )) {
            Button("好", role: .cancel) { nativeAudit.notice = nil }
        } message: { Text(nativeAudit.notice ?? "") }
    }

    @ViewBuilder
    private var chatList: some View {
        if isCompact {
            List { chatSections(compact: true) }
                .listStyle(.plain)
        } else {
            List { chatSections(compact: false) }
                .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private func chatSections(compact: Bool) -> some View {
        if !pinnedChats.isEmpty {
            Section {
                if !pinnedCollapsed {
                    ForEach(pinnedChats) { chat in
                        if compact {
                            chatLink(chat)
                                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        } else {
                            chatLink(chat)
                        }
                    }
                }
            } header: {
                Button {
                    withAnimation(.snappy(duration: 0.24)) { pinnedCollapsed.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text("置顶")
                        Spacer()
                        Image(systemName: pinnedCollapsed ? "chevron.down.circle" : "chevron.up.circle")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .textCase(nil)
                .accessibilityLabel(pinnedCollapsed ? "展开置顶聊天" : "收起置顶聊天")
            }
        }

        Section {
            ForEach(normalChats) { chat in
                if compact {
                    chatLink(chat)
                        .listRowBackground(Color(uiColor: .systemBackground))
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                } else {
                    chatLink(chat)
                }
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

// NATIVE_BAR_AUDIT2_BEGIN
// Read-only inspection of the ORIGINAL system tab bar. This is intentionally
// not another custom tab bar, effect layer, selection lens, or animation demo.
@available(iOS 26.0, *)
@MainActor
private final class WCNativeBarAudit: NSObject, ObservableObject {
    @Published private(set) var status = "原系统底栏 · 未采样"
    @Published var notice: String?

    private weak var host: UIView?
    private weak var nativeBar: UITabBar?
    private var link: CADisplayLink?
    private var proxy: WCNativeBarAuditProxy?
    private var nodes: [WCNativeBarAuditNode] = []
    private var records: [String] = []
    private var startedAt: CFTimeInterval = 0
    private var frameCount = 0
    private var savedURL: URL?
    private var truncatedTree = false
    private var sampledNodeTotal = 0
    private var saveError: String?

    func attach(_ view: UIView) { host = view }
    func detach() { stop(); host = nil }

    private func descendants(of root: UIView, limit: Int = 1600) -> [UIView] {
        var queue = [root]
        var index = 0
        while index < queue.count && index < limit {
            let remaining = max(0, limit - queue.count)
            if remaining > 0 { queue.append(contentsOf: queue[index].subviews.prefix(remaining)) }
            index += 1
        }
        return Array(queue.prefix(limit))
    }

    private func findTabBar() -> UITabBar? {
        guard let window = host?.window else { return nil }
        return descendants(of: window).compactMap { $0 as? UITabBar }.first {
            $0.window === window && !$0.isHidden && $0.alpha > 0.05
                && $0.bounds.width > 150 && ($0.items?.count ?? 0) >= 4
        }
    }

    private func heading() -> [String] {
        ["wcdemo NATIVE_BAR_AUDIT2", "OS=\(UIDevice.current.systemVersion)",
         "native TabView/search/minimize unchanged; no geometry/effect/alpha writes", 
         "Sampling: 8 seconds, requested 15 FPS; model + presentation values.",
         "No label text, accessibility labels, contacts, messages, tokens or image bytes recorded.",
         "UIView object IDs are process-local; missing objects are reported, not reconstructed."]
    }

    func start() {
        stop()
        savedURL = nil
        saveError = nil
        records = heading()
        guard let bar = findTabBar() else {
            records.append("ERROR: No visible UITabBar found. No UI changed.")
            appendWindowOutline()
            persist()
            status = "未找到 UITabBar；已记录窗口结构"
            notice = "没有找到当前可见的 UITabBar，界面未改动。请点“分享诊断文件”发送结构记录。"
            return
        }
        nativeBar = bar
        appendTree(bar, tag: "BEGIN")
        let all = descendants(of: bar)
        let candidates = all.filter {
            let name = NSStringFromClass(type(of: $0)).lowercased()
            return $0 === bar || $0 is UIVisualEffectView || $0 is UIControl
                || name.contains("glass") || name.contains("lens") || name.contains("platter")
                || name.contains("tabbar") || name.contains("search")
        }
        sampledNodeTotal = candidates.count
        nodes = candidates.prefix(90).map(WCNativeBarAuditNode.init)
        records.append("sampleNodes=\(nodes.count) candidates=\(sampledNodeTotal) partial=\(sampledNodeTotal > nodes.count)")
        startedAt = CACurrentMediaTime()
        frameCount = 0
        let target = WCNativeBarAuditProxy(owner: self)
        proxy = target
        let ticker = CADisplayLink(target: target, selector: #selector(WCNativeBarAuditProxy.tick(_:)))
        ticker.preferredFramesPerSecond = 15
        ticker.add(to: .main, forMode: .common)
        link = ticker
        status = "正在采样 8 秒；可操作原底栏"
        sample(now: startedAt)
    }

    fileprivate func sample(now: CFTimeInterval) {
        guard link != nil else { return }
        let elapsed = now - startedAt
        guard elapsed <= 8, frameCount < 160 else { stop(); return }
        guard let bar = nativeBar, bar.window != nil else {
            records.append("native tab bar detached while sampling")
            stop()
            return
        }
        frameCount += 1
        records.append(String(format: "FRAME %d t=%.4f", frameCount, elapsed))
        let reference = bar.layer.presentation()
        for node in nodes {
            guard let view = node.view else {
                records.append("  \(node.id) released")
                continue
            }
            guard view === bar || view.isDescendant(of: bar) else {
                records.append("  \(node.id) detached")
                continue
            }
            let model = view.convert(view.bounds, to: bar)
            let presentation = view.layer.presentation()
            var visible = "none"
            if let presentation, let reference {
                visible = NSStringFromCGRect(presentation.convert(presentation.bounds, to: reference))
            }
            records.append("  \(node.id) \(node.name) model=\(NSStringFromCGRect(model))"
                + " presentation=\(visible) bounds=\(NSStringFromCGRect(view.bounds))"
                + " a=\(view.alpha) pa=\(presentation?.opacity ?? Float(view.alpha)) hidden=\(view.isHidden)")
        }
    }

    func stop() {
        guard link != nil else { return }
        link?.invalidate()
        link = nil
        proxy = nil
        records.append("END samplingFrames=\(frameCount)")
        if let bar = nativeBar { appendTree(bar, tag: "END") }
        nodes.removeAll()
        persist()
        if let saveError { status = "采样已完成；保存失败：\(saveError)" }
        else { status = "采样已完成，可分享诊断文件" }
    }

    private func describe(_ view: UIView, relativeTo reference: UIView) -> String {
        var result = "\(ObjectIdentifier(view)) \(NSStringFromClass(type(of: view)))"
            + " rect=\(NSStringFromCGRect(view.convert(view.bounds, to: reference)))"
            + " bounds=\(NSStringFromCGRect(view.bounds)) a=\(view.alpha) hidden=\(view.isHidden)"
            + " interactive=\(view.isUserInteractionEnabled) clips=\(view.clipsToBounds)"
            + " transform=\(NSStringFromCGAffineTransform(view.transform))"
            + " layer=\(NSStringFromClass(type(of: view.layer))) corner=\(view.layer.cornerRadius)"
            + " animations=[\(view.layer.animationKeys()?.joined(separator: ",") ?? "")]"
        if let fx = view as? UIVisualEffectView {
            result += " effect=\(fx.effect.map { NSStringFromClass(type(of: $0)) } ?? "nil")"
            if let effect = fx.effect as? UIGlassContainerEffect { result += " fusionSpacing=\(effect.spacing)" }
            if let effect = fx.effect as? UIGlassEffect { result += " glassInteractive=\(effect.isInteractive)" }
        }
        if let control = view as? UIControl {
            result += " controlEnabled=\(control.isEnabled) selected=\(control.isSelected) highlighted=\(control.isHighlighted)"
        }
        return result
    }

    private func appendTree(_ bar: UITabBar, tag: String) {
        records.append("--- \(tag) NATIVE TAB TREE ---")
        var count = 0
        truncatedTree = false
        func walk(_ view: UIView, depth: Int) {
            guard count < 600, depth < 24 else { truncatedTree = true; return }
            count += 1
            records.append(String(repeating: "  ", count: depth) + describe(view, relativeTo: bar))
            for child in view.subviews { walk(child, depth: depth + 1) }
        }
        walk(bar, depth: 0)
        records.append("treeNodes=\(count) partial=\(truncatedTree)")
        // Some system material hosts can be beside, rather than inside, the
        // public UITabBar. Record only ancestor/direct-child class + geometry.
        var parent = bar.superview
        for level in 1...3 {
            guard let current = parent else { break }
            records.append("ancestor\(level): " + describe(current, relativeTo: bar))
            for child in current.subviews.prefix(40) {
                records.append("  directChild: " + describe(child, relativeTo: bar))
            }
            if current.subviews.count > 40 { records.append("  directChildren partial=true") }
            parent = current.superview
        }
    }

    private func appendWindowOutline() {
        guard let window = host?.window else { records.append("No host window."); return }
        let all = descendants(of: window, limit: 700)
        records.append("--- WINDOW CLASS/GEOMETRY OUTLINE; bounded to 700 nodes ---")
        for view in all { records.append(describe(view, relativeTo: window)) }
        records.append("windowNodes=\(all.count); partial=\(all.count >= 700)")
    }

    private func persist() {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            saveError = "文档目录不可用"
            return
        }
        let url = directory.appendingPathComponent("wcdemo_NATIVE_BAR_AUDIT2.txt")
        do {
            try records.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            savedURL = url
            saveError = nil
        } catch { saveError = error.localizedDescription }
    }

    private func ensureReport() {
        stop()
        guard records.isEmpty else { return }
        records = heading()
        records.append("STATIC SNAPSHOT ONLY: 8-second sampling has not been started.")
        if let bar = findTabBar() { appendTree(bar, tag: "STATIC") }
        else { appendWindowOutline() }
        persist()
    }

    func copyReport() {
        ensureReport()
        UIPasteboard.general.string = records.joined(separator: "\n")
        notice = "诊断已复制。仅包含底栏控件结构、位置和动画状态，不含聊天文字或凭据。"
    }

    func shareReport() {
        ensureReport()
        guard var presenter = host?.window?.rootViewController else {
            notice = "当前窗口不可用，可用“复制诊断”取出记录。"
            return
        }
        while let presented = presenter.presentedViewController { presenter = presented }
        let items: [Any] = savedURL.map { [$0 as Any] } ?? [records.joined(separator: "\n")]
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        }
        presenter.present(sheet, animated: true)
    }
}

@available(iOS 26.0, *)
@MainActor
private final class WCNativeBarAuditNode {
    weak var view: UIView?
    let id: String
    let name: String
    init(_ view: UIView) {
        self.view = view
        id = String(describing: ObjectIdentifier(view))
        name = NSStringFromClass(type(of: view))
    }
}

@available(iOS 26.0, *)
@MainActor
private final class WCNativeBarAuditProxy: NSObject {
    weak var owner: WCNativeBarAudit?
    init(owner: WCNativeBarAudit) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) {
        guard let owner else { link.invalidate(); return }
        owner.sample(now: link.timestamp)
    }
}

@available(iOS 26.0, *)
private struct WCNativeBarAuditAttachment: UIViewRepresentable {
    let audit: WCNativeBarAudit
    func makeUIView(context: Context) -> WCNativeBarAuditProbe {
        let view = WCNativeBarAuditProbe()
        view.audit = audit
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ uiView: WCNativeBarAuditProbe, context: Context) { audit.attach(uiView) }
    static func dismantleUIView(_ uiView: WCNativeBarAuditProbe, coordinator: ()) { uiView.audit?.detach() }
}

@available(iOS 26.0, *)
@MainActor
private final class WCNativeBarAuditProbe: UIView {
    weak var audit: WCNativeBarAudit?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { audit?.attach(self) }
        else { audit?.detach() }
    }
}
// NATIVE_BAR_AUDIT2_END
