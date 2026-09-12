import SwiftUI
import PhotosUI

struct ProfileSelection: Identifiable { let id: String }

@available(iOS 26.0, *)
struct ProfileEditor: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let profileID: String
    @State private var name = ""
    @State private var avatarKey: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var importing = false
    @State private var loaded = false
    @State private var importID = UUID()
    @State private var problem: String?
    private var isGroup: Bool { store.chats.first { $0.id == profileID }?.isGroup ?? false }
    private var title: String { isGroup ? "群资料" : (profileID == "me" ? "我的资料" : "头像与备注") }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    PhotosPicker(selection: $photoItem, matching: .images, preferredItemEncoding: .compatible) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarPreview
                            Image(systemName: "camera.fill").font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary).frame(width: 32, height: 32)
                                .glassEffect(.regular, in: Circle()).offset(x: 5, y: 5)
                        }
                    }.disabled(importing)
                    if importing { ProgressView("正在读取照片…") }
                    else { Text("轻点头像，从本机照片中选择").font(.footnote).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                if avatarKey != nil {
                    Button("使用默认头像", role: .destructive) { avatarKey = nil; photoItem = nil }
                        .disabled(importing)
                }
            }
            Section {
                TextField(isGroup ? "群名称" : "昵称 / 备注", text: $name)
                    .textInputAutocapitalization(.never)
            } header: {
                Text(isGroup ? "群名称" : "昵称 / 备注")
            } footer: {
                Text("保存后会同步显示在聊天列表、通讯录和消息旁。")
            }
            if let problem {
                Section { Text(problem).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("取消") { importID = UUID(); dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    if store.saveProfile(id: profileID, name: name, avatarKey: avatarKey) { dismiss() }
                    else { problem = store.errorMessage ?? "暂时无法保存，请重试。" }
                }
                .fontWeight(.semibold)
                .disabled(importing || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            guard !loaded else { return }
            name = store.profile(profileID).name; avatarKey = store.profile(profileID).avatarKey; loaded = true
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            let token = UUID(); importID = token
            importing = true; problem = nil
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw LocalDataError.invalidImage }
                    let key = try await store.importImage(data, maxPixel: 512)
                    guard token == importID else { store.media.removeUnreferencedImport(key); return }
                    avatarKey = key
                } catch { if token == importID { problem = error.localizedDescription } }
                if token == importID { importing = false }
            }
        }
    }
    private var avatarPreview: some View {
        Group {
            if let key = avatarKey, let image = store.media.image(key, maxPixel: 256) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                let person = store.profile(profileID)
                DemoAvatar(symbol: person.symbol, color: person.color, size: 100)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
