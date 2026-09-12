import SwiftUI

@available(iOS 26.0, *)
struct ContactsView: View {
    @EnvironmentObject private var store: DemoStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("新的朋友", systemImage: "person.badge.plus")
                    Label("群聊", systemImage: "person.3.fill")
                    Label("标签", systemImage: "tag.fill")
                    Label("服务号", systemImage: "bag.fill")
                }

                Section("我的企业") {
                    Label("黑海岸", systemImage: "water.waves")
                    Label("莫塔里", systemImage: "seal.fill")
                }

                Section("A") {
                    ForEach(store.contacts.prefix(2)) { contact in contactLink(contact) }
                }
                Section("Q") {
                    ForEach(store.contacts.dropFirst(2).prefix(2)) { contact in contactLink(contact) }
                }
                Section("S") {
                    ForEach(store.contacts.dropFirst(4)) { contact in contactLink(contact) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("通讯录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { } label: { Image(systemName: "person.badge.plus") }
                }
            }
        }
    }

    private func contactLink(_ contact: DemoContact) -> some View {
        NavigationLink {
            ContactDetailView(contactID: contact.id)
        } label: {
            HStack(spacing: 12) {
                DemoAvatar(symbol: contact.symbol, color: contact.color, size: 42)
                Text(contact.name)
            }
        }
    }
}

@available(iOS 26.0, *)
struct ContactDetailView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let contactID: String
    @State private var showDelete = false

    private var contact: DemoContact {
        store.contact(contactID) ?? DemoContact(id: contactID, name: "联系人", symbol: "person.fill", color: .gray)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    DemoAvatar(symbol: contact.symbol, color: contact.color, size: 68)
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
                NavigationLink("设置备注和标签") { Text("演示页") }
                HStack { Text("朋友权限"); Spacer(); Text("聊天、朋友圈").foregroundStyle(.secondary) }
            }

            Section {
                NavigationLink {
                    ChatView(chatID: store.chats.contains(where: { $0.id == contactID }) ? contactID : "xixi")
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
        .alert("删除联系人？", isPresented: $showDelete) {
            Button("删除", role: .destructive) {
                store.deleteContact(contactID)
                dismiss()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("这是离线 Demo，只影响当前运行。")
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
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        DemoAvatar(symbol: "person.crop.circle.fill", color: .blue, size: 72)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("漂泊者").font(.title3.bold())
                            Text("微信号：Rover26").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "qrcode").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
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
            ForEach(store.contacts) { contact in
                Button {
                    if selected.contains(contact.id) { selected.remove(contact.id) }
                    else { selected.insert(contact.id) }
                } label: {
                    HStack(spacing: 12) {
                        DemoAvatar(symbol: contact.symbol, color: contact.color, size: 42)
                        Text(contact.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: selected.contains(contact.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected.contains(contact.id) ? Color.wxGreen : Color.secondary)
                    }
                }
            }
        }
        .navigationTitle("发起群聊")
        .searchable(text: $searchText, prompt: "搜索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    _ = store.createGroup(memberIDs: Array(selected))
                    dismiss()
                }
                .disabled(selected.isEmpty)
            }
        }
    }
}

@available(iOS 26.0, *)
struct FakePhotoPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    let onDone: ([String]) -> Void

    private let photos = (1...15).map { "photo_\($0)" }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photos, id: \.self) { name in
                        ZStack(alignment: .bottomTrailing) {
                            Image(name)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 138)
                                .clipped()
                            Image(systemName: selected.contains(name) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected.contains(name) ? Color.wxGreen : Color.white)
                                .shadow(radius: 2)
                                .padding(7)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selected.contains(name) { selected.remove(name) }
                            else { selected.insert(name) }
                        }
                    }
                }
            }
            .navigationTitle("照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDone(Array(selected).sorted())
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(selected.isEmpty)
                }
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
