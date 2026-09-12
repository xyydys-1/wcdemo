import SwiftUI
import PhotosUI
import UIKit

@available(iOS 26.0, *)
struct ChatView: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String

    private var chat: DemoChat { store.chat(chatID) }

    var body: some View {
        ZStack {
            chatBackground

            ScrollView(.vertical) {
                LazyVStack(spacing: 10) {
                    ForEach(store.messages[chatID] ?? []) { message in
                        MessageRow(message: message)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.primary)
                }
                .tint(Color.primary)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ChatDetailView(chatID: chatID)
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.primary)
                }
                .tint(Color.primary)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(chatID: chatID)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var chatBackground: some View {
        GeometryReader { proxy in
            if let image = store.chatWallpapers[chatID] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.035))
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }
        .ignoresSafeArea()
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

@available(iOS 26.0, *)
private struct MessageRow: View {
    @EnvironmentObject private var store: DemoStore
    let message: DemoMessage

    var body: some View {
        switch message.kind {
        case .time(let text):
            HStack {
                Spacer()
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: Capsule())
                Spacer()
            }
            .padding(.vertical, 4)

        case .text(let text):
            bubbleRow {
                Text(text)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .glassEffect(
                        .regular.tint(
                            message.incoming
                                ? Color(uiColor: .secondarySystemBackground).opacity(0.72)
                                : Color.wxBubbleGreen.opacity(0.72)
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }

        case .photo(let name):
            bubbleRow {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 168, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

        case .photoStack(let names):
            bubbleRow {
                PhotoStackMessage(names: names)
            }
        }
    }

    @ViewBuilder
    private func bubbleRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.incoming {
                senderAvatar
                content()
                Spacer(minLength: 48)
            } else {
                Spacer(minLength: 48)
                content()
                DemoAvatar(symbol: "person.fill", color: .gray, size: 38)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.incoming ? .leading : .trailing)
    }

    @ViewBuilder
    private var senderAvatar: some View {
        if let senderID = message.senderID, let c = store.contact(senderID) {
            DemoAvatar(symbol: c.symbol, color: c.color, size: 38)
        } else {
            DemoAvatar(symbol: "person.fill", color: .pink, size: 38)
        }
    }
}

@available(iOS 26.0, *)
private struct PhotoStackMessage: View {
    let names: [String]
    @State private var expanded = false
    @State private var frontIndex = 0
    @GestureState private var dragX: CGFloat = 0

    private var cards: [String] { Array(names.prefix(4)) }

    var body: some View {
        ZStack {
            ForEach(cards.indices, id: \.self) { index in
                card(index)
            }
        }
        .frame(width: 206, height: 166)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !expanded else { return }
            withAnimation(.spring(duration: 0.44, bounce: 0.18)) {
                expanded = true
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .updating($dragX) { value, state, _ in
                    if !expanded { state = value.translation.width }
                }
                .onEnded { value in
                    guard !expanded, cards.count > 1 else { return }
                    let projected = value.predictedEndTranslation.width
                    guard abs(projected) > 38 else { return }
                    let delta = projected < 0 ? 1 : -1
                    withAnimation(.spring(duration: 0.42, bounce: 0.22)) {
                        frontIndex = normalized(frontIndex + delta)
                    }
                }
        )
        .accessibilityLabel("图片组，轻点展开，左右滑动切换")
    }

    @ViewBuilder
    private func card(_ index: Int) -> some View {
        let relative = relativeIndex(for: index)

        Image(cards[index])
            .resizable()
            .scaledToFill()
            .frame(width: 184, height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(expanded ? 0.11 : 0.18), radius: expanded ? 3 : 5, y: 2)
            .scaleEffect(scale(for: relative))
            .rotationEffect(.degrees(rotation(for: relative) + dragRotation(for: relative)))
            .offset(x: xOffset(for: relative) + dragOffset(for: relative), y: yOffset(for: relative))
            .zIndex(zIndex(for: relative))
            .onTapGesture {
                guard expanded else { return }
                withAnimation(.spring(duration: 0.46, bounce: 0.2)) {
                    frontIndex = index
                    expanded = false
                }
            }
            .animation(.spring(duration: 0.46, bounce: 0.18), value: expanded)
            .animation(.spring(duration: 0.42, bounce: 0.2), value: frontIndex)
    }

    private func normalized(_ value: Int) -> Int {
        guard !cards.isEmpty else { return 0 }
        return (value % cards.count + cards.count) % cards.count
    }

    private func relativeIndex(for index: Int) -> Int {
        guard !cards.isEmpty else { return 0 }
        return normalized(index - frontIndex)
    }

    private func zIndex(for relative: Int) -> Double {
        Double(cards.count - relative)
    }

    private func scale(for relative: Int) -> CGFloat {
        if expanded { return 0.51 }
        let scales: [CGFloat] = [1.0, 0.975, 0.95, 0.925]
        return scales[min(relative, scales.count - 1)]
    }

    private func rotation(for relative: Int) -> Double {
        if expanded {
            let values = [-1.5, 1.2, 1.0, -1.0]
            return values[min(relative, values.count - 1)]
        }
        let values = [-4.5, 3.2, -2.2, 1.5]
        return values[min(relative, values.count - 1)]
    }

    private func xOffset(for relative: Int) -> CGFloat {
        if expanded {
            let values: [CGFloat] = [-51, 51, -51, 51]
            return values[min(relative, values.count - 1)]
        }
        let values: [CGFloat] = [0, 4, -2, 2]
        return values[min(relative, values.count - 1)]
    }

    private func yOffset(for relative: Int) -> CGFloat {
        if expanded {
            let values: [CGFloat] = [-34, -34, 36, 36]
            return values[min(relative, values.count - 1)]
        }
        let values: [CGFloat] = [2, -4, -8, -12]
        return values[min(relative, values.count - 1)]
    }

    private func dragOffset(for relative: Int) -> CGFloat {
        guard !expanded else { return 0 }
        if relative == 0 { return dragX }
        return dragX * CGFloat(max(0.0, 0.10 - Double(relative) * 0.02))
    }

    private func dragRotation(for relative: Int) -> Double {
        guard !expanded, relative == 0 else { return 0 }
        return Double(dragX / 32)
    }
}

@available(iOS 26.0, *)
private struct ChatComposer: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String
    @State private var input = ""
    @State private var showPlus = false
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 8) {
            if showPlus {
                PlusPanel {
                    showPicker = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    Button { } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 50, height: 50)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())

                    HStack(spacing: 9) {
                        TextField("", text: $input)
                            .foregroundStyle(.primary)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.send)
                            .onSubmit(send)
                        Image(systemName: "face.smiling")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .glassEffect(.regular.interactive(), in: Capsule())

                    Button {
                        withAnimation(.spring(duration: 0.32, bounce: 0.16)) {
                            showPlus.toggle()
                        }
                    } label: {
                        Image(systemName: showPlus ? "xmark" : "plus")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 50, height: 50)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            FakePhotoPicker { selected in
                store.sendPhotos(selected, to: chatID)
                showPicker = false
                withAnimation { showPlus = false }
            }
        }
    }

    private func send() {
        store.sendText(input, to: chatID)
        input = ""
    }
}

@available(iOS 26.0, *)
private struct PlusPanel: View {
    var onPhotos: () -> Void

    private struct PlusItem: Identifiable {
        let id: Int
        let title: String
        let symbol: String
        let color: Color
    }

    private let items: [PlusItem] = [
        PlusItem(id: 0, title: "照片", symbol: "photo.on.rectangle", color: .blue),
        PlusItem(id: 1, title: "拍摄", symbol: "camera.fill", color: .indigo),
        PlusItem(id: 2, title: "视频通话", symbol: "video.fill", color: .green),
        PlusItem(id: 3, title: "位置", symbol: "location.fill", color: .green),
        PlusItem(id: 4, title: "红包", symbol: "envelope.fill", color: .red),
        PlusItem(id: 5, title: "转账", symbol: "arrow.left.arrow.right", color: .orange),
        PlusItem(id: 6, title: "礼物", symbol: "gift.fill", color: .pink),
        PlusItem(id: 7, title: "语音输入", symbol: "waveform", color: .blue)
    ]

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(items) { item in
                    Button {
                        if item.id == 0 { onPhotos() }
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 23, weight: .medium))
                                .foregroundStyle(item.color)
                                .frame(width: 54, height: 48)
                            Text(item.title)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(12)
    }
}

@available(iOS 26.0, *)
struct ChatDetailView: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String
    @State private var wallpaperItem: PhotosPickerItem?

    private var chat: DemoChat { store.chat(chatID) }
    private var hasWallpaper: Bool { store.chatWallpapers[chatID] != nil }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    DemoAvatar(symbol: chat.avatarSymbol, color: chat.avatarColor, size: 58)
                    if chat.isGroup {
                        DemoAvatar(symbol: "person.fill", color: .pink, size: 58)
                    }
                    Button { } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 23, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 58, height: 58)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                }
                .padding(.vertical, 6)
            }

            Section {
                NavigationLink("查找聊天内容") {
                    Text("演示搜索页")
                        .navigationTitle("查找聊天内容")
                        .toolbar(.hidden, for: .tabBar)
                }
            }

            Section {
                Toggle("消息免打扰", isOn: mutedBinding)
                Toggle("置顶聊天", isOn: pinnedBinding)
                Toggle("提醒", isOn: .constant(false))
            }

            Section {
                PhotosPicker(selection: $wallpaperItem, matching: .images) {
                    HStack {
                        Text("设置当前聊天背景")
                            .foregroundStyle(Color.wxGreen)
                        Spacer()
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                if hasWallpaper {
                    Button("恢复默认聊天背景") {
                        store.chatWallpapers.removeValue(forKey: chatID)
                        wallpaperItem = nil
                    }
                }
            }

            Section {
                Button("清空聊天记录", role: .destructive) {
                    store.messages[chatID] = []
                }
            }
        }
        .navigationTitle(chat.isGroup ? "群聊详情" : "聊天详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: wallpaperItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await MainActor.run {
                    store.chatWallpapers[chatID] = image
                }
            }
        }
    }

    private var pinnedBinding: Binding<Bool> {
        Binding(
            get: { store.pinned.contains(chatID) },
            set: { value in
                if value { store.pinned.insert(chatID) } else { store.pinned.remove(chatID) }
            }
        )
    }

    private var mutedBinding: Binding<Bool> {
        Binding(
            get: { store.muted.contains(chatID) },
            set: { value in
                if value { store.muted.insert(chatID) } else { store.muted.remove(chatID) }
            }
        )
    }
}
