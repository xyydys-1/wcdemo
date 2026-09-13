import Foundation

@main
struct LocalDataTests {
    static func main() throws {
        try migrationTests()
        try springTests()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("WeChat26Tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = LocalArchiveFile(directory: root)
        try expect(try file.load() == nil, "A new installation has no saved archive")

        var original = DemoSeed.make()
        for chat in original.chats {
            try expect(original.messages[chat.id]?.contains { !$0.kind.summary.isEmpty } == true,
                       "Seeded preview must point to real messages: \(chat.id)")
        }
        try expect(original.messages.values.flatMap { $0 }.allSatisfy { $0.kind.photoKeys.isEmpty },
                   "Preloaded history contains text and timestamps only")
        let keys = (0..<12).map { "local:photo-\($0).jpg" }
        let message = DemoMessage(senderID: "me", incoming: false, kind: .photoStack(keys))
        original.messages["shore", default: []].append(message)
        original.me.name = "我的新昵称"; original.me.avatarKey = "local:me.jpg"
        original.contacts[0].name = "新备注"; original.contacts[0].avatarKey = "local:friend.png"
        original.chats[0].title = "自定义群名"; original.chats[0].avatarKey = "local:group.jpg"
        original.wallpapers["shore"] = "local:wallpaper.jpg"
        original.drafts["shore"] = "尚未发送的笔记"
        original.pinned = ["shore"]; original.muted = ["family"]
        original.reminders = ["shore"]; original.hiddenChats = ["qiushui"]
        try file.save(original)

        // A new disk object represents the next process, with no shared in-memory state.
        let fresh = LocalArchiveFile(directory: root)
        let roundTrip = try require(try fresh.load()).archive
        try expect(try canonical(original) == canonical(roundTrip), "All durable fields round-trip")
        let restoredMessage = try require(roundTrip.messages["shore"]?.last)
        try expect(restoredMessage.id == message.id, "Message identity survives restart")
        try expect(restoredMessage.kind.photoKeys == keys, "More than four photos keep their selection order")
        try expect(roundTrip.messages["shore"]?.last?.id != roundTrip.messages["xixi"]?.last?.id,
                   "Each conversation keeps its own message history")

        var cleared = roundTrip
        cleared.messages["shore"] = []; cleared.drafts["shore"] = ""
        cleared.chats = []; cleared.contacts = []
        try fresh.save(cleared)
        let emptyReload = try require(try LocalArchiveFile(directory: root).load()).archive
        try expect(emptyReload.messages["shore"]?.isEmpty == true && emptyReload.chats.isEmpty,
                   "Intentionally empty records are loaded, never reseeded")
        try expect(emptyReload.contacts.isEmpty, "Deleting every contact persists")

        try Data("interrupted-or-damaged-file".utf8).write(to: file.archiveURL)
        let recovery = try require(try file.load())
        try expect(recovery.recovered, "A damaged current archive recovers the previous complete revision")
        try expect(try canonical(recovery.archive) == canonical(original), "Recovery retains the last complete revision")
        try file.save(recovery.archive)
        try Data("damaged-again".utf8).write(to: file.archiveURL)
        try expect(try require(try file.load()).recovered, "Saving after recovery never replaces the backup with corrupt data")

        let broken = Data("unreadable".utf8)
        try broken.write(to: file.archiveURL); try broken.write(to: file.backupURL)
        do { _ = try file.load(); throw Failure("Both damaged archives must report an error") }
        catch LocalDataError.unreadableArchive {}
        try expect(try Data(contentsOf: file.archiveURL) == broken, "Recovery failure preserves the original file")

        var future = original; future.schemaVersion = 99
        try JSONEncoder().encode(future).write(to: file.archiveURL)
        try JSONEncoder().encode(original).write(to: file.backupURL)
        do { _ = try file.load(); throw Failure("Future archives must not silently downgrade to a backup") }
        catch LocalDataError.unsupportedVersion {}
        try Data("{\"schemaVersion\":99,\"newFormat\":true}".utf8).write(to: file.archiveURL)
        do { _ = try file.load(); throw Failure("Version is checked before decoding a future payload") }
        catch LocalDataError.unsupportedVersion {}

        let blocked = root.appendingPathComponent("not-a-directory")
        try Data("occupied".utf8).write(to: blocked)
        do {
            try LocalArchiveFile(directory: blocked).save(original)
            throw Failure("Write failures must be surfaced")
        } catch is Failure { throw Failure("Write failures must be surfaced") }
        catch { }
        print("PASS: text-only examples, 0.3.0 migration, spring response, disk round-trip, avatars/names/settings/drafts, photo order, stable IDs, isolated chats, empty-state retention, recovery, future-version guard, write failure")
    }

    struct Failure: Error { let description: String; init(_ description: String) { self.description = description } }
    static func expect(_ condition: @autoclosure () throws -> Bool, _ description: String) throws {
        if try !condition() { throw Failure(description) }
    }
    static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw Failure("Expected a saved value") }; return value
    }
    static func canonical(_ archive: DemoArchive) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(archive)
    }
}
