import SwiftUI
import PhotosUI
import UIKit

enum ProfileTarget: Hashable { case me, contact(String), group(String) }

@available(iOS 26.0, *)
struct ProfileEditorView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let target: ProfileTarget
    @State private var name = ""
    @State private var item: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    var body: some View {
        Form {
            Section {
                HStack { Spacer(); avatarPreview.frame(width: 92, height: 92); Spacer() }
                PhotosPicker(selection: $item, matching: .images) { Label("从图库选择头像", systemImage: "photo") }
            }
            Section { TextField(fieldPrompt, text: $name) }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        .onAppear { load() }
        .onChange(of: item) { _, value in Task { if let value, let data = try? await value.loadTransferable(type: Data.self), let image = UIImage(data: data) { pickedImage = image } } }
    }

    private var title: String { switch target { case .me: return "个人资料"; case .contact: return "修改资料"; case .group: return "群资料" } }
    private var fieldPrompt: String { if case .group = target { return "群名" }; return "昵称 / 备注" }
    @ViewBuilder private var avatarPreview: some View {
        if let pickedImage { Image(uiImage: pickedImage).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)) }
        else { switch target { case .me: ProfileAvatar(id: "me", size: 92); case .contact(let id): ProfileAvatar(id: id, size: 92); case .group(let id): ChatAvatar(chat: store.chat(id), size: 92) } }
    }
    private func load() { switch target { case .me: name = store.profileName("me"); case .contact(let id): name = store.profileName(id); case .group(let id): name = store.chat(id).title } }
    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch target { case .me: store.updateSelf(name: clean, avatar: pickedImage); case .contact(let id): store.updateContact(id, name: clean, avatar: pickedImage); case .group(let id): store.updateGroup(id, name: clean, avatar: pickedImage) }
    }
}

@available(iOS 26.0, *)
struct NewContactView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    var body: some View {
        Form {
            Section {
                HStack { Spacer(); Group { if let image { Image(uiImage: image).resizable().scaledToFill() } else { DemoAvatar(symbol: "person.fill", colorName: "blue", size: 86) } }.frame(width:86,height:86).clipShape(RoundedRectangle(cornerRadius:20,style:.continuous)); Spacer() }
                PhotosPicker(selection: $item, matching: .images) { Label("选择头像", systemImage: "photo") }
            }
            Section { TextField("昵称 / 备注", text: $name) }
        }
        .navigationTitle("新的朋友").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("保存") { store.addContact(name: name.trimmingCharacters(in: .whitespacesAndNewlines), avatar: image); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        .onChange(of: item) { _, value in Task { if let value, let data = try? await value.loadTransferable(type: Data.self), let decoded = UIImage(data: data) { image = decoded } } }
    }
}
