import SwiftUI
import UIKit
import PhotosUI

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
    @State private var showMorphTest1b = false
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
                            Button("扫一扫", systemImage: "qrcode.viewfinder") { }
                            Button("收付款", systemImage: "qrcode") { path.append(.quick(.payment)) }
                            Divider()
                            Button("底栏形变 TEST1b", systemImage: "capsule") { showMorphTest1b = true }
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
        .fullScreenCover(isPresented: $showMorphTest1b) {
            WCMorphLabScreen { showMorphTest1b = false }
                .ignoresSafeArea()
        }
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

// MORPH_TEST1B_GEOMETRY_BEGIN
// UIKit-free geometry; also compiled by the standalone regression tests.
struct WCMorphGeometry {
    static let growthEnd: CGFloat = 0.80
    let left: CGRect
    let right: CGRect
    let envelope: CGRect
    let progress: CGFloat
    var gap: CGFloat { right.minX - left.maxX }

    static func clamp(_ value: CGFloat) -> CGFloat {
        value.isFinite ? min(1, max(0, value)) : 0
    }

    static func smooth(_ value: CGFloat) -> CGFloat {
        let t = clamp(value)
        return t * t * (3 - 2 * t)
    }

    static func inverseSmooth(_ value: CGFloat) -> CGFloat {
        let target = clamp(value)
        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0..<28 {
            let mid = (low + high) * 0.5
            if smooth(mid) < target { low = mid } else { high = mid }
        }
        return (low + high) * 0.5
    }

    static func sample(progress: CGFloat, width: CGFloat, height: CGFloat = 56,
                       separatedGap: CGFloat = 16) -> WCMorphGeometry {
        let p = clamp(progress)
        let h = max(1, height.isFinite ? height : 56)
        let gap = max(0, separatedGap.isFinite ? separatedGap : 16)
        let w = max(2 * h + gap, width.isFinite ? width : 320)
        let growth = smooth(p / growthEnd)
        let splitting = smooth((p - growthEnd) / (1 - growthEnd))
        let total = h + (w - h) * growth
        let x = (w - total) * 0.5
        // Before growthEnd, the right circle is INSIDE the long capsule.
        // Only after the continuous capsule reaches full width do we retract
        // its right edge and expose the separate circle. No third glass view.
        let left = CGRect(x: x, y: 0, width: total - (h + gap) * splitting, height: h)
        let right = CGRect(x: x + total - h, y: 0, width: h, height: h)
        return WCMorphGeometry(left: left, right: right, envelope: left.union(right), progress: p)
    }

    static func recoverProgress(left: CGRect, right: CGRect, width: CGFloat,
                                height: CGFloat = 56, separatedGap: CGFloat = 16) -> CGFloat {
        let w = max(2 * height + separatedGap, width)
        let outer = left.union(right).width
        if left.maxX >= right.maxX - 0.000001 {
            return growthEnd * inverseSmooth((outer - height) / max(1, w - height))
        }
        let retreat = (w - left.width) / max(1, height + separatedGap)
        return clamp(growthEnd + (1 - growthEnd) * inverseSmooth(retreat))
    }
}
// MORPH_TEST1B_GEOMETRY_END

// MORPH_TEST1B_NATIVE_BEGIN
// One persistent native container + two persistent outer glass surfaces.
// No swizzling, private classes, snapshots, masks, or replacement-ball fade.
@available(iOS 26.0, *)
@MainActor
@objc(WCMorphNativeBarView)
final class WCMorphNativeBarView: UIView {
    static let barHeight: CGFloat = 56
    private(set) var progress: CGFloat = 1
    private(set) var targetExpanded = true
    private(set) var selectedIndex = 1
    private(set) var fusionSpacing: CGFloat = 8
    private(set) var usesClearMaterial = false
    var animationDuration: TimeInterval = 0.55
    var onProgress: ((CGFloat) -> Void)?
    var onSelection: ((Int) -> Void)?
    var onSearch: (() -> Void)?
    var onEvent: ((String) -> Void)?

    private let fusionEffect = UIGlassContainerEffect()
    private let fusionView = UIVisualEffectView()
    private let leftGlass = UIVisualEffectView()
    private let rightGlass = UIVisualEffectView()
    private let selectionGlass = UIVisualEffectView()
    private let labelHost = UIView()
    private let searchButton = UIButton(type: .custom)
    private let avatarButton = UIButton(type: .custom)
    private let avatarImage = UIImageView()
    private var tabButtons: [UIButton] = []
    private var morphAnimator: UIViewPropertyAnimator?
    private var selectionAnimator: UIViewPropertyAnimator?
    private var displayLink: CADisplayLink?
    private var linkProxy: WCMorphDisplayLinkProxy?
    private var lastSize = CGSize.zero
    private var animationEpoch = 0
    private var isBuildingAnimator = false
    private var selectionMaterialVisible = false
    private var manualScrubbing = false
    private let titles = ["微信", "通讯录", "发现", "我"]
    private let symbols = ["message.fill", "person.2.fill", "safari.fill", "person.fill"]
    private let outerGap: CGFloat = 16

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
        fusionEffect.spacing = fusionSpacing
        fusionView.effect = fusionEffect
        fusionView.clipsToBounds = false
        addSubview(fusionView)
        for surface in [leftGlass, rightGlass] {
            surface.cornerConfiguration = .capsule()
            surface.clipsToBounds = false
            fusionView.contentView.addSubview(surface)
        }
        // Selection is INSIDE the left surface, not a third sibling in fusionView.
        selectionGlass.cornerConfiguration = .capsule()
        selectionGlass.isUserInteractionEnabled = false
        leftGlass.contentView.addSubview(selectionGlass)
        leftGlass.contentView.addSubview(labelHost)
        makeTabButtons()
        searchButton.setImage(UIImage(systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .regular)), for: .normal)
        searchButton.tintColor = .label
        searchButton.accessibilityLabel = "搜索"
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        rightGlass.contentView.addSubview(searchButton)
        avatarImage.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImage.tintColor = .systemGreen
        avatarImage.contentMode = .scaleAspectFill
        avatarImage.clipsToBounds = true
        avatarImage.layer.cornerRadius = (Self.barHeight - 6) * 0.5
        avatarImage.isUserInteractionEnabled = false
        avatarButton.addSubview(avatarImage)
        avatarButton.accessibilityLabel = "展开底栏"
        avatarButton.addTarget(self, action: #selector(avatarTapped), for: .touchUpInside)
        rightGlass.contentView.addSubview(avatarButton)
        installMaterial()
        NotificationCenter.default.addObserver(self, selector: #selector(appResignedActive),
            name: UIApplication.willResignActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func outerMaterial() -> UIGlassEffect {
        let effect = UIGlassEffect(style: usesClearMaterial ? .clear : .regular)
        effect.isInteractive = true
        return effect
    }

    private func installMaterial() {
        // Called only on initialization or an explicit material change, never per frame.
        leftGlass.effect = outerMaterial()
        rightGlass.effect = outerMaterial()
    }

    private func makeTabButtons() {
        for index in titles.indices {
            let button = UIButton(type: .custom)
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: symbols[index],
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            configuration.imagePlacement = .top
            configuration.imagePadding = 2
            configuration.title = titles[index]
            configuration.contentInsets = .zero
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var attributes = incoming
                attributes.font = UIFont.systemFont(ofSize: 10, weight: .medium)
                return attributes
            }
            button.configuration = configuration
            button.tag = index
            button.accessibilityLabel = titles[index]
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            labelHost.addSubview(button)
            tabButtons.append(button)
        }
        updateTabColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A native press can request layout. Do NOT overwrite its geometry if
        // our own bounds did not change; this is essential for native distortion.
        guard bounds.size != lastSize, bounds.width > 0 else { return }
        let wasRunning = morphAnimator?.isRunning == true
        let destination = targetExpanded
        let saved = visibleProgress()
        cancelAnimator()
        lastSize = bounds.size
        fusionView.frame = CGRect(origin: .zero, size: bounds.size)
        layoutContents()
        progress = saved
        applyGeometry(saved)
        updateContents(animated: false)
        if wasRunning && window != nil && !isBuildingAnimator {
            setExpanded(destination, animated: true)
        }
    }

    private func geometry(_ p: CGFloat) -> WCMorphGeometry {
        WCMorphGeometry.sample(progress: p, width: bounds.width,
            height: Self.barHeight, separatedGap: outerGap)
    }

    private func applyGeometry(_ p: CGFloat) {
        let g = geometry(p)
        leftGlass.frame = g.left
        rightGlass.frame = g.right
    }

    private func layoutContents() {
        let h = Self.barHeight
        let final = geometry(1)
        labelHost.frame = CGRect(x: 5, y: 3, width: final.left.width - 10, height: h - 6)
        let itemWidth = labelHost.bounds.width / CGFloat(tabButtons.count)
        for (index, button) in tabButtons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * itemWidth, y: 0,
                                  width: itemWidth, height: labelHost.bounds.height)
        }
        selectionGlass.frame = selectionFrame()
        searchButton.frame = CGRect(x: 0, y: 0, width: h, height: h)
        avatarButton.frame = searchButton.frame
        avatarImage.frame = avatarButton.bounds.insetBy(dx: 3, dy: 3)
    }

    private func selectionFrame() -> CGRect {
        guard tabButtons.indices.contains(selectedIndex) else { return .zero }
        let item = tabButtons[selectedIndex].frame
        return CGRect(x: labelHost.frame.minX + item.minX, y: 5,
                      width: item.width, height: Self.barHeight - 10)
    }

    func setAvatar(_ image: UIImage) {
        avatarImage.image = image
        avatarImage.tintColor = nil
        onEvent?("avatar=custom-image")
    }

    func setClearMaterial(_ clear: Bool) {
        guard usesClearMaterial != clear else { return }
        stopAtCurrentPosition()
        usesClearMaterial = clear
        installMaterial()
        onEvent?("material=\(clear ? "clear" : "regular")")
    }

    func setFusionSpacing(_ spacing: CGFloat) {
        // Keep the final gap safely greater than spacing, otherwise the two
        // surfaces can remain fused even at the nominal expanded endpoint.
        fusionSpacing = min(12, max(2, spacing))
        fusionEffect.spacing = fusionSpacing
        fusionView.effect = fusionEffect
        onEvent?(String(format: "fusionSpacing=%.1f finalGap=16", Double(fusionSpacing)))
    }

    @objc func setExpanded(_ expanded: Bool, animated: Bool = true) {
        layoutIfNeeded()
        if targetExpanded == expanded && morphAnimator?.isRunning == true { return }
        targetExpanded = expanded
        manualScrubbing = false
        onEvent?("target=\(expanded ? "expanded" : "collapsed")")
        // Hide the inner lens BEFORE contraction, not after the bar is squeezed.
        if !expanded {
            stopSelectionAnimator()
            setSelectionMaterial(visible: false, animated: animated)
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled, window != nil else {
            cancelAnimator()
            progress = expanded ? 1 : 0
            UIView.performWithoutAnimation { self.applyGeometry(self.progress) }
            updateContents(animated: false)
            onProgress?(progress)
            return
        }
        if let animator = morphAnimator, animator.state == .active {
            // Reverse the SAME native animation. Do not reset its start frame.
            animator.isReversed = !expanded
            if !animator.isRunning { animator.continueAnimation(withTimingParameters: nil, durationFactor: 1) }
            startDisplayLink()
            updateContents(animated: true)
            return
        }
        let destination: CGFloat = expanded ? 1 : 0
        guard abs(progress - destination) > 0.0001 else {
            updateContents(animated: false)
            return
        }
        buildAnimator(startingAt: progress)
        guard let animator = morphAnimator else { return }
        animator.isReversed = !expanded
        animator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
        startDisplayLink()
        updateContents(animated: true)
    }

    private func buildAnimator(startingAt start: CGFloat) {
        cancelAnimator()
        isBuildingAnimator = true
        defer { isBuildingAnimator = false }
        let epoch = animationEpoch
        UIView.performWithoutAnimation { self.applyGeometry(0) }
        let duration = max(0.15, animationDuration)
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut)
        animator.scrubsLinearly = true
        // Samples describe a geometric path, not a handwritten rendering or
        // spring simulation. UIKit animates the real glass views themselves.
        // Only UIKit-owned layers participate; no SwiftUI layer is animated here.
        let steps = 60
        let frames = (1...steps).map { geometry(CGFloat($0) / CGFloat(steps)) }
        animator.addAnimations { [weak self] in
            guard let self = self else { return }
            UIView.animateKeyframes(withDuration: duration, delay: 0,
                options: [.calculationModeLinear], animations: {
                    for (index, frame) in frames.enumerated() {
                        UIView.addKeyframe(withRelativeStartTime: Double(index) / Double(steps),
                            relativeDuration: 1 / Double(steps)) {
                                self.leftGlass.frame = frame.left
                                self.rightGlass.frame = frame.right
                        }
                    }
                }, completion: nil)
        }
        animator.addCompletion { [weak self] position in
            guard let self = self, self.animationEpoch == epoch else { return }
            self.morphAnimator = nil
            self.stopDisplayLink()
            self.progress = position == .start ? 0 : 1
            self.targetExpanded = self.progress > 0.5
            UIView.performWithoutAnimation { self.applyGeometry(self.progress) }
            self.updateContents(animated: true)
            self.onProgress?(self.progress)
            self.onEvent?("finished=\(self.targetExpanded ? "expanded" : "collapsed")")
        }
        morphAnimator = animator
        animator.startAnimation()
        animator.pauseAnimation()
        animator.fractionComplete = WCMorphGeometry.clamp(start)
        progress = start
    }

    func scrub(to value: CGFloat) {
        let p = WCMorphGeometry.clamp(value)
        cancelAnimator()
        manualScrubbing = true
        targetExpanded = p >= progress
        progress = p
        UIView.performWithoutAnimation { self.applyGeometry(p) }
        updateContents(animated: false)
        onProgress?(p)
    }

    func stopAtCurrentPosition() {
        let p = visibleProgress()
        stopSelectionAnimator()
        cancelAnimator()
        progress = p
        UIView.performWithoutAnimation { self.applyGeometry(p) }
        updateContents(animated: false)
    }

    private func cancelAnimator() {
        animationEpoch += 1
        if let animator = morphAnimator, animator.state == .active {
            animator.stopAnimation(true)
        }
        morphAnimator = nil
        stopDisplayLink()
    }

    private func visibleProgress() -> CGFloat {
        guard morphAnimator != nil,
              let left = leftGlass.layer.presentation(),
              let right = rightGlass.layer.presentation() else { return progress }
        return WCMorphGeometry.recoverProgress(left: left.frame, right: right.frame,
            width: bounds.width, height: Self.barHeight, separatedGap: outerGap)
    }

    private func setSelectionMaterial(visible: Bool, animated: Bool) {
        guard visible != selectionMaterialVisible else { return }
        selectionMaterialVisible = visible
        let effect: UIGlassEffect? = visible ? UIGlassEffect(style: .regular) : nil
        effect?.isInteractive = true
        if animated {
            UIView.animate(withDuration: 0.12, delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]) {
                    self.selectionGlass.effect = effect
            }
        } else {
            UIView.performWithoutAnimation { self.selectionGlass.effect = effect }
        }
    }

    private func updateContents(animated: Bool) {
        let expandedContent = progress >= 0.965 && (targetExpanded || manualScrubbing)
        let collapsedContent = progress <= 0.035
        labelHost.isHidden = !expandedContent
        searchButton.isHidden = !expandedContent
        avatarButton.isHidden = !collapsedContent
        let still = morphAnimator?.isRunning != true
        labelHost.isUserInteractionEnabled = expandedContent && still
        searchButton.isUserInteractionEnabled = expandedContent && still
        avatarButton.isUserInteractionEnabled = collapsedContent && still
        setSelectionMaterial(visible: expandedContent, animated: animated)
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let proxy = WCMorphDisplayLinkProxy(owner: self)
        linkProxy = proxy
        let link = CADisplayLink(target: proxy, selector: #selector(WCMorphDisplayLinkProxy.tick(_:)))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        linkProxy = nil
    }

    fileprivate func displayTick() {
        // Observation only: this callback never writes the glass frames.
        progress = visibleProgress()
        updateContents(animated: true)
        onProgress?(progress)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopAtCurrentPosition() }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // The unused space around the center ball must not eat list touches.
        let g = geometry(progress)
        return UIBezierPath(roundedRect: g.left, cornerRadius: Self.barHeight * 0.5).contains(point)
            || UIBezierPath(roundedRect: g.right, cornerRadius: Self.barHeight * 0.5).contains(point)
    }

    @objc private func appResignedActive() { stopAtCurrentPosition() }
    @objc private func searchTapped() { onSearch?() }
    @objc private func avatarTapped() { setExpanded(true, animated: true) }

    @objc private func tabTapped(_ sender: UIButton) {
        guard tabButtons.indices.contains(sender.tag) else { return }
        let displayedFrame = selectionGlass.layer.presentation()?.frame
        if let current = selectionAnimator, current.state == .active { current.stopAnimation(true) }
        if let frame = displayedFrame { selectionGlass.frame = frame }
        selectedIndex = sender.tag
        updateTabColors()
        let animator = UIViewPropertyAnimator(duration: 0.28, dampingRatio: 0.86) { [weak self] in
            guard let self = self else { return }
            self.selectionGlass.frame = self.selectionFrame()
        }
        selectionAnimator = animator
        animator.addCompletion { [weak self, weak animator] _ in
            if let self = self, self.selectionAnimator === animator { self.selectionAnimator = nil }
        }
        animator.startAnimation()
        onSelection?(selectedIndex)
        onEvent?("selected=\(selectedIndex)")
    }

    private func stopSelectionAnimator() {
        guard let animator = selectionAnimator else { return }
        if animator.state == .active { animator.stopAnimation(true) }
        selectionAnimator = nil
        selectionGlass.frame = selectionFrame()
    }

    private func updateTabColors() {
        for (index, button) in tabButtons.enumerated() {
            var configuration = button.configuration
            configuration?.baseForegroundColor = index == selectedIndex ? .systemGreen : .label
            button.configuration = configuration
            button.accessibilityTraits = index == selectedIndex ? [.button, .selected] : [.button]
        }
    }

    func diagnosticLine() -> String {
        let g = geometry(progress)
        let stage: String
        if progress <= 0.001 { stage = "ball" }
        else if progress < WCMorphGeometry.growthEnd { stage = "continuous" }
        else if progress < 0.999 { stage = "split/fuse" }
        else { stage = "expanded" }
        return String(format: "p=%.4f stage=%@ target=%@ size=%.1fx56 leftW=%.2f gap=%.2f spacing=%.1f material=%@ animator=%@",
            Double(progress), stage, targetExpanded ? "expand" : "collapse", Double(bounds.width),
            Double(g.left.width), Double(g.gap), Double(fusionSpacing),
            usesClearMaterial ? "clear" : "regular", morphAnimator?.isRunning == true ? "running" : "idle")
    }
}

@available(iOS 26.0, *)
@MainActor
private final class WCMorphDisplayLinkProxy: NSObject {
    weak var owner: WCMorphNativeBarView?
    init(owner: WCMorphNativeBarView) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) { owner?.displayTick() }
}
// MORPH_TEST1B_NATIVE_END

// MORPH_TEST1B_LAB_BEGIN
@available(iOS 26.0, *)
@MainActor
private struct WCMorphLabScreen: UIViewControllerRepresentable {
    let onClose: () -> Void
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = WCMorphLabViewController()
        controller.onClose = onClose
        return UINavigationController(rootViewController: controller)
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    static func dismantleUIViewController(_ controller: UINavigationController, coordinator: ()) {
        (controller.viewControllers.first as? WCMorphLabViewController)?.stopTesting()
    }
}

@available(iOS 26.0, *)
@MainActor
private final class WCMorphLabViewController: UIViewController, UITableViewDataSource,
    UITableViewDelegate, PHPickerViewControllerDelegate {
    var onClose: (() -> Void)?
    private let bar = WCMorphNativeBarView()
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let header = UIView()
    private let controls = UIStackView()
    private let progressSlider = UISlider()
    private let progressLabel = UILabel()
    private let diagnosticLabel = UILabel()
    private let slowSwitch = UISwitch()
    private let scrollSwitch = UISwitch()
    private let spacingSlider = UISlider()
    private let spacingLabel = UILabel()
    private var events: [String] = []
    private var scrollAccumulator: CGFloat = 0
    private var lastScrollOffset: CGFloat = 0
    private var selected = 1
    private let tabTitles = ["微信", "通讯录", "发现", "我"]
    private var sampleNames: [String] {
        switch selected {
        case 0: return ["文件传输助手", "底栏形变测试群", "系统玻璃验证"] + (1...36).map { String(format: "测试会话 %02d", $0) }
        case 1: return ["新的朋友", "群聊", "标签", "服务号"] + (1...36).map { String(format: "测试联系人 %02d", $0) }
        case 2: return ["朋友圈", "扫一扫", "看一看", "搜一搜"] + (1...36).map { "发现测试项目 \($0)" }
        default: return ["个人资料", "收藏", "相册", "设置"] + (1...36).map { "个人页测试项目 \($0)" }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "底栏形变 TEST1b"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done,
            target: self, action: #selector(closeTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "头像", style: .plain,
            target: self, action: #selector(chooseAvatar))
        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .onDrag
        table.contentInset.bottom = 86
        table.verticalScrollIndicatorInsets.bottom = 86
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        makeControls()
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        let preferredWidth = bar.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -32)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            bar.heightAnchor.constraint(equalToConstant: WCMorphNativeBarView.barHeight),
            bar.widthAnchor.constraint(lessThanOrEqualToConstant: 500), preferredWidth
        ])
        bar.onProgress = { [weak self] progress in self?.updateReadout(progress) }
        bar.onEvent = { [weak self] event in self?.record(event) }
        bar.onSelection = { [weak self] selected in
            guard let self = self else { return }
            self.selected = selected
            self.table.reloadData()
        }
        bar.onSearch = { [weak self] in
            guard let self = self else { return }
            self.record("search=opened")
            let controller = WCMorphSearchViewController(names: self.sampleNames)
            self.navigationController?.pushViewController(controller, animated: true)
        }
        record("opened TEST1b — independent lab; main TabView unchanged")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = table.bounds.width
        let fitting = controls.systemLayoutSizeFitting(
            CGSize(width: max(1, width - 32), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        let height = fitting.height + 20
        if abs(header.frame.width - width) > 0.5 || abs(header.frame.height - height) > 0.5 {
            header.frame = CGRect(x: 0, y: 0, width: width, height: height)
            controls.frame = CGRect(x: 16, y: 8, width: max(1, width - 32), height: fitting.height)
            table.tableHeaderView = header
        }
        updateReadout(bar.progress)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTesting()
    }

    func stopTesting() { bar.stopAtCurrentPosition() }

    private func makeControls() {
        controls.axis = .vertical
        controls.spacing = 9
        let explanation = UILabel()
        explanation.text = "先扩为完整长条，末段才分离；收起反向。\n拖动进度可停在任意形态；底栏外空白区域不拦触摸。"
        explanation.font = .systemFont(ofSize: 12)
        explanation.textColor = .secondaryLabel
        explanation.numberOfLines = 0
        controls.addArrangedSubview(explanation)
        let collapse = makeButton("收起", action: #selector(collapseTapped))
        let expand = makeButton("展开", action: #selector(expandTapped))
        let copy = makeButton("复制诊断", action: #selector(copyDiagnostic))
        controls.addArrangedSubview(row([collapse, expand, copy], equal: true))
        let material = UISegmentedControl(items: ["系统标准玻璃", "清透玻璃"])
        material.selectedSegmentIndex = 0
        material.addTarget(self, action: #selector(materialChanged(_:)), for: .valueChanged)
        controls.addArrangedSubview(material)
        slowSwitch.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        scrollSwitch.addTarget(self, action: #selector(scrollModeChanged), for: .valueChanged)
        controls.addArrangedSubview(row([caption("慢速 ×4"), slowSwitch, UIView(), caption("滚动触发"), scrollSwitch]))
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.value = 1
        progressSlider.accessibilityLabel = "形变进度，零为收起，一为展开"
        progressSlider.addTarget(self, action: #selector(scrubChanged), for: .valueChanged)
        progressLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        progressLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
        controls.addArrangedSubview(row([caption("进度"), progressSlider, progressLabel]))
        spacingSlider.minimumValue = 2
        spacingSlider.maximumValue = 12
        spacingSlider.value = 8
        spacingSlider.accessibilityLabel = "原生玻璃融合距离"
        spacingSlider.addTarget(self, action: #selector(spacingChanged), for: .valueChanged)
        spacingLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        spacingLabel.text = "8.0 pt"
        spacingLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
        controls.addArrangedSubview(row([caption("融合距离"), spacingSlider, spacingLabel]))
        diagnosticLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        diagnosticLabel.textColor = .secondaryLabel
        diagnosticLabel.numberOfLines = 3
        diagnosticLabel.heightAnchor.constraint(equalToConstant: 39).isActive = true
        controls.addArrangedSubview(diagnosticLabel)
        header.addSubview(controls)
        table.tableHeaderView = header
    }

    private func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.cornerStyle = .capsule
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func row(_ views: [UIView], equal: Bool = false) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.spacing = 9
        stack.alignment = .center
        stack.distribution = equal ? .fillEqually : .fill
        return stack
    }

    private func updateReadout(_ progress: CGFloat) {
        if !progressSlider.isTracking { progressSlider.value = Float(progress) }
        progressLabel.text = String(format: "%.0f%%", Double(progress) * 100)
        diagnosticLabel.text = bar.diagnosticLine()
    }

    private func record(_ event: String) {
        let time = String(format: "%.3f", ProcessInfo.processInfo.systemUptime)
        events.append("[\(time)] \(event) | \(bar.diagnosticLine())")
        if events.count > 180 { events.removeFirst(events.count - 180) }
    }

    @objc private func collapseTapped() { bar.setExpanded(false, animated: true) }
    @objc private func expandTapped() { bar.setExpanded(true, animated: true) }
    @objc private func closeTapped() { stopTesting(); onClose?() }
    @objc private func scrubChanged() { bar.scrub(to: CGFloat(progressSlider.value)) }
    @objc private func materialChanged(_ sender: UISegmentedControl) { bar.setClearMaterial(sender.selectedSegmentIndex == 1) }
    @objc private func speedChanged() {
        bar.stopAtCurrentPosition()
        bar.animationDuration = slowSwitch.isOn ? 2.2 : 0.55
        record("duration=\(bar.animationDuration)")
    }
    @objc private func scrollModeChanged() {
        scrollAccumulator = 0
        lastScrollOffset = table.contentOffset.y
        record("scroll-trigger=\(scrollSwitch.isOn)")
    }
    @objc private func spacingChanged() {
        bar.setFusionSpacing(CGFloat(spacingSlider.value))
        spacingLabel.text = String(format: "%.1f pt", spacingSlider.value)
        updateReadout(bar.progress)
    }
    @objc private func copyDiagnostic() {
        let header = """
        wcdemo GlassMorph TEST1b
        iOS=\(UIDevice.current.systemVersion) bounds=\(view.bounds.size)
        style=\(traitCollection.userInterfaceStyle.rawValue) scale=\(traitCollection.displayScale)
        reduceMotion=\(UIAccessibility.isReduceMotionEnabled) reduceTransparency=\(UIAccessibility.isReduceTransparencyEnabled)
        material=\(bar.usesClearMaterial ? "clear" : "regular") fusionSpacing=\(bar.fusionSpacing)
        duration=\(bar.animationDuration) scrollTrigger=\(scrollSwitch.isOn)
        Native objects: one UIGlassContainerEffect; two persistent outer UIGlassEffect views.
        Gap is measured geometry, not a claim about the renderer's optical seam.
        \(bar.diagnosticLine())
        """
        UIPasteboard.general.string = header + "\n\n" + events.joined(separator: "\n")
        let alert = UIAlertController(title: "诊断已复制", message: "可与录屏一起反馈。日志仅包含测试状态，不读取聊天记录或通讯录。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    @objc private func chooseAvatar() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let image = object as? UIImage else { return }
            let small = image.preparingThumbnail(of: CGSize(width: 256, height: 256)) ?? image
            DispatchQueue.main.async { self?.bar.setAvatar(small) }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sampleNames.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "\(tabTitles[selected]) · 独立测试数据" }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "morph.sample") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "morph.sample")
        let names = sampleNames
        let icons = ["person.crop.square.fill", "person.2.fill", "tag.fill", "bag.fill", "star.circle.fill", "heart.circle.fill"]
        let colors: [UIColor] = [.systemGreen, .systemBlue, .systemPurple, .systemOrange, .systemPink, .systemTeal]
        var content = cell.defaultContentConfiguration()
        content.text = names[indexPath.row]
        content.secondaryText = "观察底栏背后的内容折射与原生按压"
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: icons[indexPath.row % icons.count])
        content.imageProperties.tintColor = colors[indexPath.row % colors.count]
        content.imageProperties.maximumSize = CGSize(width: 40, height: 40)
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 76 }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let y = scrollView.contentOffset.y
        let delta = y - lastScrollOffset
        lastScrollOffset = y
        guard scrollSwitch.isOn, scrollView.isDragging || scrollView.isDecelerating,
              y > -scrollView.adjustedContentInset.top,
              y < scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom else { return }
        if (delta > 0) != (scrollAccumulator > 0) { scrollAccumulator = 0 }
        scrollAccumulator += delta
        if scrollAccumulator > 18 { bar.setExpanded(false, animated: true); scrollAccumulator = 0 }
        else if scrollAccumulator < -18 { bar.setExpanded(true, animated: true); scrollAccumulator = 0 }
    }
}

@available(iOS 26.0, *)
@MainActor
private final class WCMorphSearchViewController: UITableViewController, UISearchResultsUpdating {
    private let names: [String]
    private let searchController = UISearchController(searchResultsController: nil)
    private var filtered: [String] {
        let query = searchController.searchBar.text ?? ""
        return query.isEmpty ? names : names.filter { $0.localizedCaseInsensitiveContains(query) }
    }
    init(names: [String]) { self.names = names; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "搜索测试"
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "搜索测试数据"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    func updateSearchResults(for searchController: UISearchController) { tableView.reloadData() }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "search") ?? UITableViewCell(style: .default, reuseIdentifier: "search")
        var content = cell.defaultContentConfiguration()
        content.text = filtered[indexPath.row]
        cell.contentConfiguration = content
        return cell
    }
}
// MORPH_TEST1B_LAB_END
