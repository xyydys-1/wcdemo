import SwiftUI

@available(iOS 26.0, *)
struct ChatView: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String

    private var chat: DemoChat { store.chat(chatID) }
    private var usesWallpaper: Bool { store.wallpaperChats.contains(chatID) }

    var body: some View {
        ZStack {
            chatBackground

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.messages[chatID] ?? []) { message in
                        MessageRow(message: message)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { } label: { Image(systemName: "magnifyingglass") }
                NavigationLink {
                    ChatDetailView(chatID: chatID)
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(chatID: chatID)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var chatBackground: some View {
        if usesWallpaper {
            Image("wallpaper")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.04))
        } else {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
        }
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
                    .background(.thinMaterial, in: Capsule())
                Spacer()
            }
            .padding(.vertical, 4)

        case .text(let text):
            bubbleRow {
                Text(text)
                    .font(.system(size: 17))
                    .foregroundStyle(message.incoming ? Color.primary : Color.black)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        message.incoming ? Color(uiColor: .secondarySystemBackground) : Color.wxBubbleGreen,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                Spacer(minLength: 58)
            } else {
                Spacer(minLength: 58)
                content()
                DemoAvatar(symbol: "person.fill", color: .gray, size: 38)
            }
        }
        .frame(maxWidth: .infinity)
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

    var body: some View {
        Group {
            if expanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(Array(names.prefix(4).enumerated()), id: \.offset) { _, name in
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
                .frame(width: 180)
            } else {
                ZStack {
                    ForEach(Array(names.prefix(4).enumerated()), id: \.offset) { index, name in
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 184, height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .rotationEffect(.degrees(rotation(for: index)))
                            .offset(x: CGFloat(index) * 2.5, y: CGFloat(index) * -4.0)
                            .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
                            .zIndex(Double(names.count - index))
                    }
                }
                .frame(width: 196, height: 142)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.45, bounce: 0.18)) {
                expanded.toggle()
            }
        }
    }

    private func rotation(for index: Int) -> Double {
        let values = [-5.5, 4.0, -2.0, 1.5]
        return values[index % values.count]
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

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 8) {
                    Button { } label: {
                        Image(systemName: "mic.fill")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)

                    HStack(spacing: 8) {
                        TextField("", text: $input)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.send)
                            .onSubmit(send)
                        Image(systemName: "face.smiling")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .glassEffect()

                    Button {
                        withAnimation(.spring(duration: 0.32, bounce: 0.16)) { showPlus.toggle() }
                    } label: {
                        Image(systemName: showPlus ? "xmark" : "plus")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)
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
    private let items: [(String, String)] = [
        ("照片", "photo.on.rectangle"), ("拍摄", "camera.fill"),
        ("视频通话", "video.fill"), ("位置", "location.fill"),
        ("红包", "envelope.fill"), ("转账", "arrow.left.arrow.right"),
        ("礼物", "gift.fill"), ("语音输入", "waveform")
    ]

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Button {
                        if index == 0 { onPhotos() }
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.1)
                                .font(.system(size: 23, weight: .medium))
                                .frame(width: 54, height: 48)
                            Text(item.0)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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

    private var chat: DemoChat { store.chat(chatID) }

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
                            .font(.title2)
                            .frame(width: 58, height: 58)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.vertical, 6)
            }

            Section {
                NavigationLink("查找聊天内容") { Text("演示搜索页").navigationTitle("查找聊天内容") }
            }

            Section {
                Toggle("消息免打扰", isOn: mutedBinding)
                Toggle("置顶聊天", isOn: pinnedBinding)
                Toggle("提醒", isOn: .constant(false))
            }

            Section {
                Button(store.wallpaperChats.contains(chatID) ? "恢复默认聊天背景" : "设置当前聊天背景") {
                    if store.wallpaperChats.contains(chatID) { store.wallpaperChats.remove(chatID) }
                    else { store.wallpaperChats.insert(chatID) }
                }
                .foregroundStyle(.wxGreen)
            }

            Section {
                Button("清空聊天记录", role: .destructive) {
                    store.messages[chatID] = []
                }
            }
        }
        .navigationTitle(chat.isGroup ? "群聊详情" : "聊天详情")
        .navigationBarTitleDisplayMode(.inline)
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
