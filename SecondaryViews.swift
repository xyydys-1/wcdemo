import SwiftUI

@available(iOS 26.0, *)
struct ContactsView: View {
    @EnvironmentObject private var store: DemoStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ContactActionLabel(title: "新的朋友", symbol: "person.badge.plus")
                    NavigationLink {
                        List(store.chats.filter(\.isGroup)) { chat in
                            NavigationLink { ChatView(chatID: chat.id) } label: {
                                HStack(spacing: 12) { ProfileAvatar(id: chat.id, size: 42); Text(chat.title) }
                            }
                        }.navigationTitle("群聊").toolbar(.hidden, for: .tabBar)
                    } label: { ContactActionLabel(title: "群聊", symbol: "person.3.fill") }
                    ContactActionLabel(title: "标签", symbol: "tag.fill")
                    ContactActionLabel(title: "服务号", symbol: "bag.fill")
                }

                Section("我的企业") {
                    Label("黑海岸", systemImage: "water.waves")
                    Label("莫塔里", systemImage: "seal.fill")
                }

                Section("联系人") {
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
            }
        }
    }
}

private struct ContactActionLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol).resizable().scaledToFit()
                .frame(width: 23, height: 23)
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.wxGreen)
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
                Button("修改头像和昵称 / 备注") { showProfile = true }
                HStack { Text("朋友权限"); Spacer(); Text("聊天、朋友圈").foregroundStyle(.secondary) }
            }

            Section {
                NavigationLink {
                    ChatView(chatID: contactID)
                } label: {
                    Label("发消息", systemImage: "message.fill")
                        .foregroundStyle(Color.wxGreen)
                }
                Label("音视频通话", systemImage: "video.fill")
                    .foregroundStyle(Color.wxGreen)
            }

            Section {
                Button("删除联系人", role: .destructive) { showDelete = true }
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
                    NavigationLink { PlaceholderView(title: "朋友圈") } label: { DiscoverRow("朋友圈", "camera.fill", .blue) }
                }
                Section {
                    NavigationLink { PlaceholderView(title: "视频号") } label: { DiscoverRow("视频号", "play.rectangle.fill", .orange) }
                    NavigationLink { PlaceholderView(title: "直播") } label: { DiscoverRow("直播", "dot.radiowaves.left.and.right", .red) }
                }
                Section {
                    DiscoverRow("扫一扫", "qrcode.viewfinder", .blue)
                    DiscoverRow("摇一摇", "wave.3.right", .blue)
                }
                Section {
                    DiscoverRow("看一看", "eye.fill", .blue)
                    DiscoverRow("搜一搜", "magnifyingglass", .blue)
                }
                Section {
                    DiscoverRow("附近", "location.fill", .blue)
                    DiscoverRow("小程序", "circle.grid.2x2.fill", .purple)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("发现")
        }
    }
}

@available(iOS 26.0, *)
private struct DiscoverRow: View {
    let title: String
    let symbol: String
    let color: Color
    init(_ title: String, _ symbol: String, _ color: Color) {
        self.title = title; self.symbol = symbol; self.color = color
    }
    var body: some View {
        Label {
            Text(title).foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
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
                    Label("服务", systemImage: "square.grid.2x2.fill")
                }
                Section {
                    Label("收藏", systemImage: "cube.box.fill")
                    Label("朋友圈", systemImage: "photo.on.rectangle.angled")
                    Label("卡包", systemImage: "creditcard.fill")
                    Label("表情", systemImage: "face.smiling.fill")
                }
                Section {
                    Label("设置", systemImage: "gearshape.fill")
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
    @State private var keyword = ""

    var body: some View {
        Form {
            Section {
                TextField("账号/手机号", text: $keyword)
            }
            Section {
                Label("扫一扫", systemImage: "qrcode.viewfinder")
                Label("手机联系人", systemImage: "phone.fill")
                Label("雷达", systemImage: "dot.radiowaves.left.and.right")
                Label("面对面建群", systemImage: "person.3.fill")
            }
            Section {
                Label("公众号", systemImage: "doc.text.fill")
                Label("服务号", systemImage: "bag.fill")
            }
        }
        .navigationTitle("添加朋友")
        .toolbar(.hidden, for: .tabBar)
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
    @State private var selected: Set<String> = []
    @State private var searchText = ""

    var body: some View {
        List {
            ForEach(store.contacts.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }) { contact in
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
                    }
                }
            }
        }
        .navigationTitle("发起群聊")
        .toolbar(.hidden, for: .tabBar)
        .searchable(text: $searchText, prompt: "搜索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    if store.createGroup(memberIDs: Array(selected)) != nil { dismiss() }
                }
                .disabled(selected.isEmpty)
            }
        }
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
