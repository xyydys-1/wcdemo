import SwiftUI
import PhotosUI
import UIKit

private let groupMemberColumns: [GridItem] = Array(repeating: GridItem(.flexible()), count: 4)

@available(iOS 26.0, *)
struct ChatView: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String
    private var chat: DemoChat { store.chat(chatID) }

    var body: some View {
        ZStack {
            chatBackground
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 10) {
                        ForEach(store.messages[chatID] ?? []) { message in
                            MessageRow(message: message).id(message.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.messages[chatID]?.count ?? 0) { _, _ in
                    if let id = store.messages[chatID]?.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { } label: { Image(systemName: "magnifyingglass").foregroundStyle(.primary) }
                NavigationLink { ChatDetailView(chatID: chatID) } label: { Image(systemName: "line.3.horizontal").foregroundStyle(.primary) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(chatID: chatID).padding(.horizontal, 10).padding(.vertical, 6)
        }
        .onDisappear { store.flush() }
        .alert("错误", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("好") { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
    }

    @ViewBuilder private var chatBackground: some View {
        GeometryReader { proxy in
            if let key = store.wallpaperKey(chatID), let image = store.media.image(key) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped().overlay(Color.black.opacity(0.035))
            } else { Color(uiColor: .systemGroupedBackground) }
        }.ignoresSafeArea().ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

@available(iOS 26.0, *)
private struct MessageRow: View {
    @EnvironmentObject private var store: DemoStore
    let message: DemoMessage
    var body: some View {
        switch message.kind {
        case .time(let text):
            Text(text).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule()).frame(maxWidth: .infinity)
        case .text(let text):
            HStack(alignment: .top, spacing: 8) {
                if message.incoming { avatar }
                if !message.incoming { Spacer(minLength: 52) }
                Text(text).font(.system(size: 17)).foregroundStyle(.primary).padding(.horizontal, 14).padding(.vertical, 10)
                    .glassEffect(message.incoming ? .regular : .regular.tint(.wxBubbleGreen.opacity(0.76)), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                if message.incoming { Spacer(minLength: 52) }
                if !message.incoming { avatar }
            }
        case .photo(let key):
            HStack(alignment: .top, spacing: 8) {
                if message.incoming { avatar }
                if !message.incoming { Spacer() }
                StoredPhoto(key: key).frame(width: 190, height: 190 / max(0.4, store.media.aspect(key))).clipped().photoEdge(cornerRadius: 14)
                if message.incoming { Spacer() }
                if !message.incoming { avatar }
            }
        case .photoStack(let keys):
            HStack(alignment: .top, spacing: 8) {
                if message.incoming { avatar }
                if !message.incoming { Spacer(minLength: 22) }
                PhotoStackMessage(keys: keys, width: 252)
                if message.incoming { Spacer(minLength: 22) }
                if !message.incoming { avatar }
            }
        }
    }
    private var senderID: String { message.senderID ?? (message.incoming ? "xixi" : "me") }
    private var avatar: some View { ProfileAvatar(id: senderID, size: 42) }
}

@available(iOS 26.0, *)
private struct ChatComposer: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String
    @State private var input = ""
    @State private var showPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @FocusState private var inputFocused: Bool

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                Button { inputFocused = true } label: {
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
                        .focused($inputFocused)
                        .onSubmit(send)
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .glassEffect(.regular.interactive(), in: Capsule())

                Menu {
                    ControlGroup {
                        Button("照片", systemImage: "photo.on.rectangle") { inputFocused = false; showPhotos = true }
                        Button("拍摄", systemImage: "camera.fill") { }
                        Button("视频通话", systemImage: "video.fill") { }
                        Button("位置", systemImage: "location.fill") { }
                    }
                    ControlGroup {
                        Button("红包", systemImage: "envelope.fill") { }
                        Button("转账", systemImage: "arrow.left.arrow.right") { }
                        Button("礼物", systemImage: "gift.fill") { }
                        Button("语音输入", systemImage: "mic.fill") { inputFocused = true }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 50, height: 50)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .onAppear { input = store.draft(chatID) }
        .onChange(of: input) { _, value in store.setDraft(value, chatID: chatID) }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 30, matching: .images)
        .onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
    }

    private func send() { store.sendText(input, to: chatID); input = "" }
    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { images.append(image) }
        }
        if !images.isEmpty { store.importPhotos(images, chatID: chatID) }
        photoItems = []
    }
}

@available(iOS 26.0, *)
private struct GroupMemberCell: View {
    let id: String
    let name: String
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ProfileAvatar(id: id, size: 48)
            Text(name)
                .font(.caption)
                .lineLimit(1)
        }
        .onLongPressGesture(perform: onLongPress)
    }
}

@available(iOS 26.0, *)
private struct AddGroupMemberCell: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .light))
                    .frame(width: 48, height: 48)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("添加").font(.caption)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

@available(iOS 26.0, *)
struct ChatDetailView: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var showWallpaper = false
    @State private var showClear = false
    @State private var showAddMembers = false
    @State private var editingMember: String?
    private var chat: DemoChat { store.chat(chatID) }

    var body: some View {
        Form {
            if chat.isGroup {
                Section {
                    NavigationLink { ProfileEditorView(target: .group(chatID)) } label: {
                        HStack(spacing: 14) { ChatAvatar(chat: chat, size: 58); VStack(alignment: .leading) { Text(chat.title).font(.headline); Text("编辑群头像和群名").font(.subheadline).foregroundStyle(.secondary) } }
                    }
                }
                Section("群成员 \(chat.memberIDs.count)") {
                    LazyVGrid(columns: groupMemberColumns, spacing: 16) {
                        ForEach(chat.memberIDs, id: \.self) { id in
                            GroupMemberCell(id: id, name: store.profileName(id)) {
                                if id != "me" { editingMember = id }
                            }
                        }
                        AddGroupMemberCell { showAddMembers = true }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Section { NavigationLink { ProfileEditorView(target: .contact(chatID)) } label: { HStack(spacing: 14) { ProfileAvatar(id: chatID, size: 58); Text("修改头像和昵称 / 备注") } } }
            }
            Section {
                Toggle("消息免打扰", isOn: Binding(get: { store.muted.contains(chatID) }, set: { store.setMuted($0, for: chatID) }))
                Toggle("置顶聊天", isOn: Binding(get: { store.pinned.contains(chatID) }, set: { store.setPinned($0, for: chatID) }))
            }
            Section { Button("设置当前聊天背景") { showWallpaper = true }.foregroundStyle(Color.wxGreen) }
            Section { Button("清空聊天记录", role: .destructive) { showClear = true } }
            Section { Text("文字、图片、资料和设置均保存在本机。").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle(chat.isGroup ? "群聊详情" : "聊天详情").navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showWallpaper, selection: $wallpaperItem, matching: .images)
        .onChange(of: wallpaperItem) { _, item in Task { if let item, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { store.setWallpaper(image, chatID: chatID) }; wallpaperItem = nil } }
        .sheet(isPresented: $showAddMembers) { GroupMemberPicker(chatID: chatID) }
        .confirmationDialog("成员操作", isPresented: Binding(get: { editingMember != nil }, set: { if !$0 { editingMember = nil } })) {
            if let id = editingMember {
                Button("移出群聊", role: .destructive) { store.removeGroupMember(id, from: chatID); editingMember = nil }
            }
        }
        .alert("清空聊天记录？", isPresented: $showClear) {
            Button("清空", role: .destructive) { store.clearChat(chatID) }; Button("取消", role: .cancel) { }
        }
    }
}

@available(iOS 26.0, *)
private struct GroupMemberPicker: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let chatID: String
    @State private var selected: Set<String> = []
    var body: some View {
        NavigationStack {
            List(store.contacts) { c in
                Button { if selected.contains(c.id) { selected.remove(c.id) } else { selected.insert(c.id) } } label: {
                    HStack { ProfileAvatar(id: c.id, size: 40); Text(c.name).foregroundStyle(.primary); Spacer(); Image(systemName: selected.contains(c.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(selected.contains(c.id) ? Color.wxGreen : Color.secondary) }
                }
            }
            .navigationTitle("添加群成员")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { store.addGroupMembers(Array(selected), to: chatID); dismiss() }.disabled(selected.isEmpty) } }
        }
    }
}

struct ChatAvatar: View {
    @EnvironmentObject private var store: DemoStore
    let chat: DemoChat
    var size: CGFloat
    var body: some View {
        if let key = chat.avatarKey, let image = store.media.image(key) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size*0.24, style: .continuous))
        } else if chat.isGroup {
            let ids = Array(chat.memberIDs.prefix(4))
            LazyVGrid(columns: [GridItem(.fixed((size-3)/2), spacing: 3), GridItem(.fixed((size-3)/2), spacing: 3)], spacing: 3) {
                ForEach(ids, id: \.self) { id in ProfileAvatar(id: id, size: (size-3)/2) }
            }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size*0.24, style: .continuous))
        } else { ProfileAvatar(id: chat.id, size: size) }
    }
}
