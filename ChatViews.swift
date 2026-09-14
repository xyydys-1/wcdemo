import SwiftUI
import PhotosUI
import UIKit

@available(iOS 26.0, *)
struct ChatView: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String
    @State private var showDetails = false
    @State private var showSearch = false
    @State private var scrollTarget: UUID?
    private var chat: DemoChat { store.chat(chatID) }
    private var rows: [DemoMessage] { store.messages[chatID] ?? [] }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                chatBackground
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 10) {
                            ForEach(rows) { message in
                                MessageRow(message: message, isGroup: chat.isGroup,
                                    photoWidth: min(252, max(130, geometry.size.width - 106)),
                                    expandedPhotoWidth: min(340, max(130, geometry.size.width - 106)))
                                    .id(message.id)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 12)
                    }
                    .defaultScrollAnchor(.bottom, for: .initialOffset)
                    .defaultScrollAnchor(.top, for: .alignment)
                    .scrollDismissesKeyboard(.interactively)
                    .overlay {
                        if rows.isEmpty {
                            ContentUnavailableView("还没有消息", systemImage: "square.and.pencil",
                                description: Text("写点文字或发送照片，内容会保存在本机。"))
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: rows.last?.id) { _, id in
                        guard let id else { return }
                        withAnimation(.snappy(duration: 0.25)) { proxy.scrollTo(id, anchor: .bottom) }
                    }
                    .onChange(of: scrollTarget) { _, id in
                        guard let id else { return }
                        withAnimation(.smooth) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // One native glass group can contract back to the root's single button.
            // No separate backgrounds, spacer or manually animated opacity.
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass").foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                }
                .tint(Color.primary).accessibilityLabel("查找聊天内容")
                Button { showDetails = true } label: {
                    Image(systemName: "line.3.horizontal").foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                }
                .tint(Color.primary).accessibilityLabel("聊天详情")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(chatID: chatID)
                .padding(.horizontal, 10).padding(.vertical, 6)
        }
        .sheet(isPresented: $showDetails) { NavigationStack { ChatDetailView(chatID: chatID) } }
        .sheet(isPresented: $showSearch) {
            ChatSearchView(chatID: chatID) { id in
                scrollTarget = id; showSearch = false
            }
        }
        .onAppear { store.openChat(chatID) }
        .onDisappear { store.flush() }
    }

    private var chatBackground: some View {
        GeometryReader { proxy in
            if let key = store.state.wallpapers[chatID], let image = store.media.image(key, maxPixel: 2048) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    .overlay(Color.black.opacity(0.035))
            } else { Color(uiColor: .systemGroupedBackground) }
        }
        .ignoresSafeArea().ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

@available(iOS 26.0, *)
private struct MessageRow: View {
    @EnvironmentObject private var store: DemoStore
    let message: DemoMessage
    let isGroup: Bool
    let photoWidth: CGFloat
    let expandedPhotoWidth: CGFloat
    @State private var preview: PhotoPresentation?
    @State private var editPerson: ProfileSelection?

    var body: some View {
        content
            .fullScreenCover(item: $preview) { NativePhotoPreview(presentation: $0).ignoresSafeArea() }
            .sheet(item: $editPerson) { person in NavigationStack { ProfileEditor(profileID: person.id) } }
    }
    @ViewBuilder
    private var content: some View {
        switch message.kind {
        case .time(let text):
            HStack {
                Spacer()
                Text(text).font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .glassEffect(.regular, in: Capsule())
                Spacer()
            }.padding(.vertical, 4)
        case .text(let text):
            bubbleRow { textBubble(text) }
        case .photo(let key):
            bubbleRow {
                if store.media.isReadable(key) {
                    let ratio = max(0.05, store.media.aspect(key))
                    let width = min(photoWidth - 10, 224 * ratio)
                    StoredPhoto(source: key).frame(width: width, height: width / ratio)
                        .photoSurface(cornerRadius: 13)
                        .onTapGesture { preview = PhotoPresentation(keys: [key]) }
                } else { textBubble("图片暂时无法读取") }
            }
        case .photoStack(let keys):
            bubbleRow {
                let available = keys.filter { store.media.isReadable($0) }
                if available.isEmpty { textBubble("图片暂时无法读取") }
                else {
                    VStack(alignment: message.incoming ? .leading : .trailing, spacing: 6) {
                        PhotoStackMessage(keys: available, width: photoWidth, expandedWidth: expandedPhotoWidth)
                        if available.count != keys.count {
                            Text("另有 \(keys.count - available.count) 张照片暂时无法读取")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    private func textBubble(_ text: String) -> some View {
        Text(text).font(.system(size: 17)).foregroundStyle(.primary)
            .textSelection(.enabled)
            .padding(.horizontal, 13).padding(.vertical, 10)
            .glassEffect(.regular.tint(message.incoming
                ? Color(uiColor: .secondarySystemBackground).opacity(0.72)
                : Color.wxBubbleGreen.opacity(0.72)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    private func bubbleRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.incoming {
                avatar(message.senderID ?? "")
                VStack(alignment: .leading, spacing: 4) {
                    if isGroup { Text(store.profile(message.senderID ?? "").name).font(.caption).foregroundStyle(.secondary) }
                    content()
                }
                Spacer(minLength: 28)
            } else {
                Spacer(minLength: 28)
                content()
                avatar("me")
            }
        }
        .frame(maxWidth: .infinity, alignment: message.incoming ? .leading : .trailing)
    }
    private func avatar(_ id: String) -> some View {
        Button { editPerson = ProfileSelection(id: id) } label: { ProfileAvatar(id: id, size: 38) }
            .buttonStyle(.plain)
    }
}

@available(iOS 26.0, *)
private struct ChatComposer: View {
    @EnvironmentObject private var store: DemoStore
    let chatID: String
    @State private var input = ""
    @State private var showPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var showCamera = false
    @State private var notice: String?
    @State private var showAttachments = false
    @State private var pendingAttachment: AttachmentAction?
    @Namespace private var attachmentTransition
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Keep the 0.2.0 three-piece composer: same controls, spacing, frames and glass.
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
                            .onSubmit(send)
                            .focused($inputFocused)
                        Image(systemName: "face.smiling")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .glassEffect(.regular.interactive(), in: Capsule())

                    attachmentControl
                }
            }
        }
        .overlay(alignment: .top) {
            if importing {
                HStack(spacing: 8) { ProgressView(); Text("正在导入照片…").font(.caption) }
                    .padding(12).glassEffect(.regular, in: Capsule()).offset(y: -54)
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $photoItems, maxSelectionCount: 30,
            selectionBehavior: .ordered, matching: .images, preferredItemEncoding: .compatible)
        .sheet(isPresented: $showAttachments, onDismiss: finishAttachmentPresentation) {
            AttachmentPanel { item in
                pendingAttachment = item
                showAttachments = false
            }
            // iOS 26 supplies the inset Liquid Glass sheet. Do not replace its
            // presentation background with a material or an extra glass layer.
            .presentationDetents([.height(296)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(36)
            .navigationTransition(.zoom(sourceID: "chat.attachments", in: attachmentTransition))
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                guard let image, let data = image.jpegData(compressionQuality: 0.95) else { return }
                importing = true
                Task {
                    defer { importing = false }
                    do {
                        let key = try await store.importImage(data)
                        if !store.sendPhotos([key], to: chatID) { store.media.removeUnreferencedImport(key) }
                    } catch { store.errorMessage = error.localizedDescription }
                }
            }.ignoresSafeArea()
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty, !importing else { return }
            importing = true
            Task {
                _ = await store.importPhotos(items, to: chatID)
                photoItems = []; importing = false
            }
        }
        .onAppear { input = store.draft(for: chatID) }
        .onChange(of: input) { _, value in store.setDraft(value, for: chatID) }
        .onChange(of: store.state.drafts[chatID]) { _, saved in
            let value = saved ?? ""
            if store.draft(for: chatID) == value, input != value { input = value }
        }
        .onDisappear { store.setDraft(input, for: chatID); store.flush() }
        .alert("提示", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("好", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
    }
    private func send() {
        if store.sendText(input, to: chatID) { input = "" }
    }
    private var plusLabel: some View {
        Image(systemName: "plus")
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 50, height: 50)
            .contentShape(Circle())
    }
    @ViewBuilder private var attachmentControl: some View {
        if store.compactAttachmentMenu {
            Menu {
                ControlGroup {
                    attachmentButton(.photos)
                    attachmentButton(.camera)
                    attachmentButton(.video)
                    attachmentButton(.location)
                }
                ControlGroup {
                    attachmentButton(.envelope)
                    attachmentButton(.transfer)
                    attachmentButton(.gift)
                    attachmentButton(.dictation)
                }
            } label: { plusLabel }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .menuOrder(.fixed)
            .labelStyle(.titleAndIcon)
            .tint(.primary)
            .accessibilityLabel("添加附件")
            .disabled(importing)
        } else {
            Button {
                inputFocused = false
                pendingAttachment = nil
                showAttachments = true
            } label: { plusLabel }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .matchedTransitionSource(id: "chat.attachments", in: attachmentTransition)
            .accessibilityLabel("添加附件")
            .disabled(importing)
        }
    }
    private func finishAttachmentPresentation() {
        guard let item = pendingAttachment else { return }
        pendingAttachment = nil
        // Present the picker/camera only after the panel has actually dismissed.
        attachmentAction(item)
    }
    private func attachmentButton(_ item: AttachmentAction) -> some View {
        Button { attachmentAction(item) } label: {
            Label(item.title, systemImage: item.symbol)
        }
    }
    private func attachmentAction(_ item: AttachmentAction) {
        inputFocused = false
        switch item {
        case .photos: showPicker = true
        case .camera:
            if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
            else { notice = "当前设备无法使用相机，可以从照片中选择图片。" }
        case .dictation: inputFocused = true; notice = "轻点系统键盘上的麦克风，即可听写文字。"
        default: notice = "当前版本暂不支持\(item.title)。"
        }
    }
}

private enum AttachmentAction: Int, CaseIterable, Identifiable {
    case photos, camera, video, location, envelope, transfer, gift, dictation
    var id: Int { rawValue }
    var title: String { ["照片", "拍摄", "视频通话", "位置", "红包", "转账", "礼物", "语音输入"][rawValue] }
    var symbol: String { ["photo.on.rectangle", "camera.fill", "video.fill", "location.fill",
        "wallet.bifold.fill", "arrow.left.arrow.right", "gift.fill", "mic.fill"][rawValue] }
}

@available(iOS 26.0, *)
private struct AttachmentPanel: View {
    let select: (AttachmentAction) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 22) {
            ForEach(AttachmentAction.allCases) { item in
                VStack(spacing: 9) {
                    Button { select(item) } label: {
                        Image(systemName: item.symbol)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(AttachmentTileStyle())
                    .accessibilityLabel(item.title)
                    Text(item.title).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary).lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// The outer surface is the system's Liquid Glass sheet. Its content tiles use
// a native frosted material; Button owns activation, cancellation and scrolling.
// The only custom press treatment is the small SwiftUI spring enlargement.
private struct AttachmentTileStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 19, style: .continuous)
        return configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background {
                shape.fill(.ultraThinMaterial)
                    .overlay { shape.fill(Color.gray.opacity(configuration.isPressed ? 0.20 : 0.12)) }
            }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 1.02 : 1.075) : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.25, bounce: 0.24),
                       value: configuration.isPressed)
    }
}

@available(iOS 26.0, *)
struct ChatDetailView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let chatID: String
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var importing = false
    @State private var showClear = false
    @State private var wallpaperProblem: String?
    @State private var editProfile: ProfileSelection?
    @State private var showMembers = false
    private var chat: DemoChat { store.chat(chatID) }

    var body: some View {
        Form {
            Section {
                Button { editProfile = ProfileSelection(id: chatID) } label: {
                    HStack(spacing: 14) {
                        ProfileAvatar(id: chatID, size: 58)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(chat.title).font(.headline).foregroundStyle(.primary)
                            Text(chat.isGroup ? "编辑群头像和群名" : "编辑头像和备注")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain)
            }
            if chat.isGroup {
                Section("群成员（\(chat.memberIDs.count)）") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 20) {
                        ForEach(chat.memberIDs, id: \.self) { id in
                            Button { editProfile = ProfileSelection(id: id) } label: {
                                VStack(spacing: 8) {
                                    ProfileAvatar(id: id, size: 58)
                                    Text(store.profile(id).name).font(.system(size: 14))
                                        .foregroundStyle(.primary).lineLimit(1)
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(.plain)
                            .contextMenu {
                                Button("编辑头像和昵称", systemImage: "pencil") { editProfile = ProfileSelection(id: id) }
                                if id != "me" {
                                    Button("移出群聊", systemImage: "person.fill.xmark", role: .destructive) {
                                        store.removeGroupMember(id, from: chatID)
                                    }
                                }
                            }
                        }
                        Button { showMembers = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus").font(.system(size: 25, weight: .light))
                                    .foregroundStyle(.secondary).frame(width: 58, height: 58)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    }
                                Text("添加").font(.system(size: 14)).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).accessibilityLabel("添加群成员")
                    }.padding(.vertical, 10)
                }
            }
            Section {
                Toggle(isOn: Binding(get: { store.muted.contains(chatID) }, set: { store.setMuted($0, for: chatID) })) {
                    ArtworkLabel(title: "消息免打扰", artwork: "mute")
                }
                Toggle(isOn: Binding(get: { store.pinned.contains(chatID) }, set: { store.setPinned($0, for: chatID) })) {
                    ArtworkLabel(title: "置顶聊天", artwork: "pin")
                }
                Toggle(isOn: Binding(get: { store.state.reminders.contains(chatID) }, set: { store.setReminder($0, for: chatID) })) {
                    ArtworkLabel(title: "提醒", artwork: "bell")
                }
            }
            Section {
                PhotosPicker(selection: $wallpaperItem, matching: .images, preferredItemEncoding: .compatible) {
                    HStack {
                        ArtworkLabel(title: "设置当前聊天背景", artwork: "photo")
                        Spacer()
                        if importing { ProgressView() }
                    }
                }.disabled(importing)
                if store.state.wallpapers[chatID] != nil {
                    Button { store.setWallpaper(nil, for: chatID); wallpaperItem = nil } label: {
                        ArtworkLabel(title: "恢复默认聊天背景", artwork: "photo")
                    }
                }
                if let wallpaperProblem { Text(wallpaperProblem).font(.footnote).foregroundStyle(.red) }
            }
            Section {
                Button(role: .destructive) { showClear = true } label: {
                    ArtworkLabel(title: "清空聊天记录", artwork: "trash", titleColor: .red)
                }
            } footer: { Text("文字、图片、资料和设置均保存在本机。") }
        }
        .navigationTitle(chat.isGroup ? "群聊详情" : "聊天详情")
        .navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        .sheet(item: $editProfile) { selection in NavigationStack { ProfileEditor(profileID: selection.id) } }
        .sheet(isPresented: $showMembers) { NavigationStack { CreateGroupView(groupID: chatID) } }
        .alert("清空聊天记录？", isPresented: $showClear) {
            Button("清空", role: .destructive) { store.clearMessages(chatID) }
            Button("取消", role: .cancel) {}
        } message: { Text("此会话的本地消息会被删除，重新打开后也不会恢复。") }
        .onChange(of: wallpaperItem) { _, item in
            guard let item else { return }
            importing = true; wallpaperProblem = nil
            Task {
                defer { importing = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw LocalDataError.invalidImage }
                    let key = try await store.importImage(data)
                    if !store.setWallpaper(key, for: chatID) {
                        store.media.removeUnreferencedImport(key)
                        wallpaperProblem = store.errorMessage
                    }
                } catch { wallpaperProblem = error.localizedDescription }
            }
        }
    }
}

@available(iOS 26.0, *)
private struct ChatSearchView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let chatID: String
    let onSelect: (UUID) -> Void
    @State private var query = ""
    private var matches: [DemoMessage] {
        (store.messages[chatID] ?? []).filter { !$0.kind.summary.isEmpty && (query.isEmpty || $0.kind.summary.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        NavigationStack {
            List(matches) { message in
                Button { onSelect(message.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.profile(message.senderID ?? "me").name).font(.caption).foregroundStyle(.secondary)
                        Text(message.kind.summary).foregroundStyle(.primary).lineLimit(3)
                    }.padding(.vertical, 4)
                }
            }
            .searchable(text: $query, prompt: "查找文字或图片")
            .navigationTitle("查找聊天内容").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
