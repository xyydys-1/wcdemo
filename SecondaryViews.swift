import SwiftUI

@available(iOS 26.0, *)
struct ContactsView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var showNew = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showNew = true } label: { ContactActionLabel(title: "新的朋友", symbol: "person.badge.plus") }
                    NavigationLink { CreateGroupView() } label: { ContactActionLabel(title: "群聊", symbol: "person.3.fill") }
                    ContactActionLabel(title: "标签", symbol: "tag.fill")
                    ContactActionLabel(title: "服务号", symbol: "bag.fill")
                }
                Section("联系人") { ForEach(store.contacts) { contact in contactLink(contact) } }
            }
            .listStyle(.insetGrouped).navigationTitle("通讯录")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "person.badge.plus").font(.system(size: 21, weight: .regular)).frame(width: 30, height: 30) } } }
            .sheet(isPresented: $showNew) { NavigationStack { NewContactView() } }
        }
    }
    private func contactLink(_ contact: DemoContact) -> some View {
        NavigationLink { ContactDetailView(contactID: contact.id) } label: { HStack(spacing: 12) { ProfileAvatar(id: contact.id, size: 42); Text(contact.name) } }
    }
}

@available(iOS 26.0, *)
private struct ContactActionLabel: View {
    let title: String; let symbol: String
    var body: some View { HStack(spacing: 12) { Image(systemName: symbol).foregroundStyle(.wxGreen).frame(width: 28); Text(title).foregroundStyle(.primary) } }
}

@available(iOS 26.0, *)
struct ContactDetailView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let contactID: String
    @State private var showDelete = false
    private var contact: DemoContact { store.contact(contactID) ?? DemoContact(id: contactID, name: "联系人", symbol: "person.fill", colorName: "gray") }
    var body: some View {
        Form {
            Section {
                NavigationLink { ProfileEditorView(target: .contact(contactID)) } label: {
                    HStack(spacing: 16) { ProfileAvatar(id: contactID, size: 68); VStack(alignment: .leading, spacing: 5) { Text(contact.name).font(.title3.bold()); Text("微信号：demo_\(contact.id)").font(.subheadline).foregroundStyle(.secondary) } }
                }
            }
            Section {
                NavigationLink { ChatView(chatID: store.ensureDirectChat(contactID)) } label: { Label("发消息", systemImage: "message.fill").foregroundStyle(.wxGreen) }
                Label("音视频通话", systemImage: "video.fill").foregroundStyle(.wxGreen)
            }
            Section { Button("删除联系人", role: .destructive) { showDelete = true } }
        }
        .navigationTitle("详细资料").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
        .alert("删除联系人？", isPresented: $showDelete) { Button("删除", role: .destructive) { store.deleteContact(contactID); dismiss() }; Button("取消", role: .cancel) { } }
    }
}

@available(iOS 26.0, *)
struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            List {
                Section { NavigationLink { PlaceholderView(title: "朋友圈") } label: { DiscoverRow("朋友圈", "camera.fill", .blue) } }
                Section { DiscoverRow("视频号", "play.rectangle.fill", .orange); DiscoverRow("直播", "dot.radiowaves.left.and.right", .red) }
                Section { DiscoverRow("扫一扫", "qrcode.viewfinder", .blue); DiscoverRow("摇一摇", "wave.3.right", .blue) }
                Section { DiscoverRow("看一看", "eye.fill", .blue); DiscoverRow("搜一搜", "magnifyingglass", .blue) }
                Section { DiscoverRow("附近", "location.fill", .blue); DiscoverRow("小程序", "circle.grid.2x2.fill", .purple) }
            }.listStyle(.insetGrouped).navigationTitle("发现")
        }
    }
}

@available(iOS 26.0, *)
private struct DiscoverRow: View {
    let title:String, symbol:String, color:Color
    init(_ title:String,_ symbol:String,_ color:Color){self.title=title;self.symbol=symbol;self.color=color}
    var body: some View { Label { Text(title).foregroundStyle(.primary) } icon: { Image(systemName:symbol).foregroundStyle(color).frame(width:28) } }
}

@available(iOS 26.0, *)
struct MeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { ProfileEditorView(target: .me) } label: {
                        HStack(spacing:16){ ProfileAvatar(id:"me",size:72); VStack(alignment:.leading,spacing:6){ Text("个人资料").font(.title3.bold()); Text("修改头像和昵称").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"qrcode").foregroundStyle(.secondary) }.padding(.vertical,10)
                    }
                }
                Section { Label("服务",systemImage:"square.grid.2x2.fill") }
                Section { Label("收藏",systemImage:"cube.box.fill"); Label("朋友圈",systemImage:"photo.on.rectangle.angled"); Label("卡包",systemImage:"creditcard.fill"); Label("表情",systemImage:"face.smiling.fill") }
                Section { NavigationLink { DemoSettingsView() } label: { Label("设置",systemImage:"gearshape.fill") } }
            }.listStyle(.insetGrouped).navigationTitle("我")
        }
    }
}

@available(iOS 26.0, *)
struct DemoSettingsView: View {
    @EnvironmentObject private var store: DemoStore
    var body: some View {
        Form {
            Section("聊天列表") {
                Picker("显示模式", selection: Binding(get:{store.chatListDisplayMode}, set:{store.setDisplayMode($0)})) { Text("默认").tag(ChatListDisplayMode.standard); Text("紧凑").tag(ChatListDisplayMode.compact) }
                Toggle("折叠置顶聊天", isOn: Binding(get:{store.pinnedCollapsed}, set:{store.setPinnedCollapsed($0)}))
            }
            Section { Text("消息、图片、头像、备注和设置均保存到本机。").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("设置")
    }
}

@available(iOS 26.0, *)
struct AddFriendView: View { var body: some View { NewContactView() } }

@available(iOS 26.0, *)
struct PaymentView: View {
    var body: some View {
        ZStack { Color.wxGreen.ignoresSafeArea(); VStack(spacing:22){ Text("收付款").font(.title2.bold()).foregroundStyle(.white); VStack(spacing:14){ Image(systemName:"barcode").resizable().scaledToFit().frame(height:82); Image(systemName:"qrcode").resizable().scaledToFit().frame(width:210,height:210); Text("向商家付款").font(.headline); Text("¥ 0.00").font(.largeTitle.bold()) }.padding(28).background(.white,in:RoundedRectangle(cornerRadius:28,style:.continuous)).foregroundStyle(.black); Spacer() }.padding(.top,28).padding(.horizontal,24) }
        .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden,for:.navigationBar).toolbar(.hidden,for:.tabBar)
    }
}

@available(iOS 26.0, *)
struct CreateGroupView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected:Set<String>=[]
    var body: some View {
        List(store.contacts){ c in Button{ if selected.contains(c.id){selected.remove(c.id)}else{selected.insert(c.id)} }label:{ HStack{ProfileAvatar(id:c.id,size:42);Text(c.name).foregroundStyle(.primary);Spacer();Image(systemName:selected.contains(c.id) ? "checkmark.circle.fill":"circle").foregroundStyle(selected.contains(c.id) ? Color.wxGreen:.secondary)} } }
        .navigationTitle("发起群聊").toolbar(.hidden,for:.tabBar).toolbar{ToolbarItem(placement:.topBarTrailing){Button("完成"){_=store.createGroup(memberIDs:Array(selected));dismiss()}.disabled(selected.isEmpty)}}
    }
}

@available(iOS 26.0, *)
struct PlaceholderView: View { let title:String; var body: some View { ContentUnavailableView(title,systemImage:"sparkles",description:Text("演示占位页面")).navigationTitle(title) } }
