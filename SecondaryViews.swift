import SwiftUI

@available(iOS 26.0, *)
struct ContactsView: View {
    @EnvironmentObject private var store: DemoStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { AddFriendView() } label: { ArtworkLabel(title: "新的朋友", artwork: "friends") }
                    NavigationLink {
                        List(store.chats.filter(\.isGroup)) { chat in
                            NavigationLink { ChatView(chatID: chat.id) } label: {
                                HStack(spacing: 12) { ProfileAvatar(id: chat.id, size: 42); Text(chat.title) }
                                    .alignmentGuide(.listRowSeparatorLeading) { _ in 54 }
                            }
                        }.navigationTitle("群聊").toolbar(.hidden, for: .tabBar)
                    } label: { ArtworkLabel(title: "群聊", artwork: "group") }
                    ArtworkLabel(title: "标签", artwork: "tag")
                    ArtworkLabel(title: "服务号", artwork: "service")
                }

                Section("我的企业") {
                    ArtworkLabel(title: "黑海岸", artwork: "wave")
                    ArtworkLabel(title: "莫塔里", artwork: "seal")
                }

                Section("联系人（\(store.contacts.count)）") {
                    ForEach(store.contacts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { contact in
                        contactLink(contact)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("通讯录")
            .toolbar {
                ToolbarItem(id: "contacts.add", placement: .topBarTrailing) {
                    NavigationLink { AddFriendView() } label: {
                        Image(systemName: "person.badge.plus")
                            .resizable().scaledToFit()
                            .frame(width: 21, height: 21)
                            .offset(x: -0.5, y: -0.5)
                            .frame(width: 24, height: 24)
                    }
                    .accessibilityLabel("添加朋友")
                }
            }
        }
    }

    private func contactLink(_ contact: DemoContact) -> some View {
        NavigationLink {
            ContactDetailView(contactID: contact.id)
        } label: {
            HStack(spacing: 12) {
                ProfileAvatar(id: contact.id, size: 42)
                Text(contact.name)
            }.alignmentGuide(.listRowSeparatorLeading) { _ in 54 }
        }
    }
}

@available(iOS 26.0, *)
struct ContactDetailView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let contactID: String
    @State private var showDelete = false
    @State private var showProfile = false

    private var contact: DemoContact {
        store.contact(contactID) ?? DemoContact(id: contactID, name: "联系人", symbol: "person.fill", color: .gray)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Button { showProfile = true } label: { ProfileAvatar(id: contact.id, size: 68) }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(contact.name).font(.title3.bold())
                        Text("微信号：demo_\(contact.id)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
            }

            Section {
                Button { showProfile = true } label: { ArtworkLabel(title: "修改头像和昵称 / 备注", artwork: "profile") }
                HStack {
                    ArtworkLabel(title: "朋友权限", artwork: "privacy")
                    Spacer()
                    Text("聊天、朋友圈").font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink {
                    ChatView(chatID: contactID)
                } label: {
                    ArtworkLabel(title: "发消息", artwork: "chat")
                }
                ArtworkLabel(title: "音视频通话", artwork: "video")
            }

            Section {
                Button(role: .destructive) { showDelete = true } label: {
                    ArtworkLabel(title: "删除联系人", artwork: "trash", titleColor: .red)
                }
            }
        }
        .navigationTitle("详细资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showProfile) { NavigationStack { ProfileEditor(profileID: contactID) } }
        .alert("删除联系人？", isPresented: $showDelete) {
            Button("删除", role: .destructive) {
                store.deleteContact(contactID)
                dismiss()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("将从本机通讯录中移除这个联系人。已有的聊天笔记仍会保留。")
        }
    }
}

@available(iOS 26.0, *)
struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { PlaceholderView(title: "朋友圈") } label: { ArtworkLabel(title: "朋友圈", artwork: "camera") }
                }
                Section {
                    NavigationLink { PlaceholderView(title: "视频号") } label: { ArtworkLabel(title: "视频号", artwork: "video") }
                    NavigationLink { PlaceholderView(title: "直播") } label: { ArtworkLabel(title: "直播", artwork: "broadcast") }
                }
                Section {
                    ArtworkLabel(title: "扫一扫", artwork: "scan")
                    ArtworkLabel(title: "摇一摇", artwork: "shake")
                }
                Section {
                    ArtworkLabel(title: "看一看", artwork: "news")
                    ArtworkLabel(title: "搜一搜", artwork: "search")
                }
                Section {
                    ArtworkLabel(title: "附近", artwork: "location")
                    ArtworkLabel(title: "小程序", artwork: "apps")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("发现")
        }
    }
}

@available(iOS 26.0, *)
struct MeView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var showProfile = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showProfile = true } label: {
                    HStack(spacing: 16) {
                        ProfileAvatar(id: "me", size: 72)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.state.me.name).font(.title3.bold()).foregroundStyle(.primary)
                            Text("微信号：Rover26").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "qrcode").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    }.buttonStyle(.plain)
                }

                Section {
                    NavigationLink { PaymentView() } label: { ArtworkLabel(title: "服务", artwork: "service") }
                }
                Section {
                    ArtworkLabel(title: "收藏", artwork: "collection")
                    ArtworkLabel(title: "朋友圈", artwork: "photo")
                    ArtworkLabel(title: "卡包", artwork: "card")
                    ArtworkLabel(title: "表情", artwork: "smile")
                }
                Section {
                    NavigationLink { DemoSettingsView() } label: { ArtworkLabel(title: "设置", artwork: "settings") }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我")
            .sheet(isPresented: $showProfile) { NavigationStack { ProfileEditor(profileID: "me") } }
        }
    }
}

@available(iOS 26.0, *)
struct AddFriendView: View {
    var body: some View {
        NewContactView()
    }
}

@available(iOS 26.0, *)
struct PaymentView: View {
    var body: some View {
        ZStack {
            Color.wxGreen.ignoresSafeArea()
            VStack(spacing: 22) {
                Text("收付款")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                VStack(spacing: 14) {
                    Image(systemName: "barcode")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 82)
                    Image(systemName: "qrcode")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                    Text("向商家付款")
                        .font(.headline)
                    Text("¥ 0.00")
                        .font(.largeTitle.bold())
                }
                .padding(28)
                .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .foregroundStyle(.black)
                Spacer()
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

@available(iOS 26.0, *)
struct CreateGroupView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    var groupID: String? = nil
    @State private var selected: Set<String> = []
    @State private var searchText = ""
    @State private var showNewContact = false
    private var existing: Set<String> { Set(groupID.map { store.chat($0).memberIDs } ?? []) }
    private var candidates: [DemoContact] {
        store.contacts.filter {
            !existing.contains($0.id) && (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        List {
            Section {
                Button { showNewContact = true } label: { ArtworkLabel(title: "添加新朋友", artwork: "friends") }
            }
            Section {
            ForEach(candidates) { contact in
                Button {
                    if selected.contains(contact.id) { selected.remove(contact.id) }
                    else { selected.insert(contact.id) }
                } label: {
                    HStack(spacing: 12) {
                        ProfileAvatar(id: contact.id, size: 42)
                        Text(contact.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: selected.contains(contact.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected.contains(contact.id) ? Color.wxGreen : Color.secondary)
                    }.alignmentGuide(.listRowSeparatorLeading) { _ in 54 }
                }
            }
            } header: { Text("已选择 \(selected.count) 人") }
            if candidates.isEmpty {
                Text(searchText.isEmpty ? "所有朋友都已在群里，可以先添加新朋友。" : "没有找到匹配的朋友。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(groupID == nil ? "发起群聊" : "添加群成员")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .searchable(text: $searchText, prompt: "搜索")
        .toolbar {
            if groupID != nil {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    let ids = store.contacts.filter { selected.contains($0.id) }.map(\.id)
                    if let groupID {
                        if store.addGroupMembers(ids, to: groupID) { dismiss() }
                    } else if store.createGroup(memberIDs: ids) != nil { dismiss() }
                }
                .disabled(selected.isEmpty)
            }
        }
        .sheet(isPresented: $showNewContact) {
            NavigationStack { NewContactView { selected.insert($0) } }
        }
    }
}

@available(iOS 26.0, *)
private struct DemoSettingsView: View {
    @EnvironmentObject private var store: DemoStore

    var body: some View {
        Form {
            Section("聊天列表") {
                Picker(selection: Binding(get: { store.chatListDisplayMode }, set: { store.setChatListDisplayMode($0) })) {
                    Text("默认").tag(ChatListDisplayMode.standard)
                    Text("紧凑").tag(ChatListDisplayMode.compact)
                } label: { ArtworkLabel(title: "显示模式", artwork: "layout") }
                Toggle(isOn: Binding(get: { store.pinnedCollapsed }, set: { store.setPinnedCollapsed($0) })) {
                    ArtworkLabel(title: "折叠置顶聊天", artwork: "pin")
                }
            }
            Section {
                Picker(selection: Binding(get: { store.compactAttachmentMenu }, set: { store.setCompactAttachmentMenu($0) })) {
                    Text("大面板").tag(false)
                    Text("菜单").tag(true)
                } label: { ArtworkLabel(title: "附件展开方式", artwork: "attachment") }
            } header: {
                Text("聊天")
            } footer: {
                Text("大面板显示两排附件；菜单保留原来的紧凑展开方式。")
            }
        }
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

@available(iOS 26.0, *)
private struct PlaceholderView: View {
    let title: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "sparkles", description: Text("演示占位页面"))
            .navigationTitle(title)
    }
}
