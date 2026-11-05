import CryptoKit
import Foundation

/// The sealed files through the shipped code: envelope, Keychain key, migration, failure modes.
@main
@MainActor
struct SealedStorageTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    /// A synthetic input that must never appear on disk outside a sealed envelope.
    static let marker = "SYNTHETIC-MARKER-7f3e-ÿ-12,5*2"
    static let keychain = KeychainSecretStore(
        scope: "sealed-storage-test-\(UUID().uuidString)", bundleIdentifier: "com.tinycast.tests")
    static var roots: [URL] = []
    static var accounts: [UUID] = []

    static func main() async {
        sealsAndOpensEnvelopes()
        refusesTamperedEnvelopes()
        writesOnlySealedPrivateFiles()
        refusesAMissingKeyOrACorruptFile()
        migratesLegacyFilesOnce()
        keepsTheNewerCopyWhenBothExist()
        erasesOneStoreAndItsKeyOnly()
        boundsTheFileSize()
        reportsAFailedWrite()
        sealsTheLauncherHistory()
        await sealsTheRankingTable()
        sealsCalculatorHistory()
        cleanUp()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    // MARK: - Envelope

    static func sealsAndOpensEnvelopes() {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data(marker.utf8)
        guard let first = try? SealedEnvelope.seal(plaintext, key: key, purpose: "a"),
            let second = try? SealedEnvelope.seal(plaintext, key: key, purpose: "a")
        else { return expect(false, "sealing succeeds") }
        expect((try? SealedEnvelope.open(first, key: key, purpose: "a")) == plaintext, "round-trips")
        expect(first.prefix(4) == Data("TCSE".utf8) && first[4] == 1, "a versioned header leads")
        expect(first.range(of: plaintext) == nil, "the plaintext is not in the envelope")
        expect(first != second, "two seals of one plaintext differ")
        expect(first.subdata(in: 5..<17) != second.subdata(in: 5..<17), "each seal takes a fresh nonce")
    }

    static func refusesTamperedEnvelopes() {
        let key = SymmetricKey(size: .bits256)
        guard let envelope = try? SealedEnvelope.seal(Data(marker.utf8), key: key, purpose: "a") else {
            return expect(false, "sealing succeeds")
        }
        func opens(_ data: Data, key: SymmetricKey = key, purpose: String = "a") -> SealedEnvelope.Failure? {
            do {
                _ = try SealedEnvelope.open(data, key: key, purpose: purpose)
                return nil
            } catch {
                return error
            }
        }
        expect(opens(envelope, key: SymmetricKey(size: .bits256)) == .authentication, "a wrong key fails")
        expect(opens(envelope, purpose: "b") == .authentication, "another store's purpose fails")
        expect(opens(envelope.prefix(20)) == .truncated, "a truncated file fails")
        var magic = envelope
        magic[0] ^= 0xFF
        expect(opens(magic) == .unknownFormat, "an edited magic fails")
        var version = envelope
        version[4] = 2
        expect(opens(version) == .unsupportedVersion, "an unknown version fails")
        let spots = [(8, "nonce"), (envelope.count / 2 + 9, "ciphertext"), (envelope.count - 1, "tag")]
        for (index, name) in spots {
            var flipped = envelope
            flipped[index] ^= 0x01
            expect(opens(flipped) == .authentication, "a flipped bit in the \(name) fails")
        }
    }

    // MARK: - SealedFile

    static func makeRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("sealed-storage-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        roots.append(root)
        return root
    }

    static func newAccount() -> UUID {
        let account = UUID()
        accounts.append(account)
        return account
    }

    static func makeFile(_ root: URL, legacy: String? = nil, account: UUID? = nil) -> SealedFile {
        SealedFile(
            name: "store.enc", legacyName: legacy, account: account ?? newAccount(), directory: root,
            keychain: keychain)
    }

    /// `try?` flattens "nothing stored" into "failed"; this keeps the two apart.
    static func read(_ file: SealedFile) -> Data?? {
        do {
            return .some(try file.read())
        } catch {
            return nil
        }
    }

    static func hasKey(_ account: UUID) -> Bool? {
        do {
            return try keychain.secret(for: account) != nil
        } catch {
            return nil
        }
    }

    static func listing(_ root: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).sorted()
    }

    static func containsMarker(_ root: URL) -> Bool {
        listing(root).contains { name in
            let data = (try? Data(contentsOf: root.appendingPathComponent(name))) ?? Data()
            return ["SYNTHETIC", "synthetic", "MARKER", "marker"].contains {
                data.range(of: Data($0.utf8)) != nil
            }
        }
    }

    static func writesOnlySealedPrivateFiles() {
        let root = makeRoot()
        let file = makeFile(root)
        expect(read(file) == .some(nil), "an absent file reads as nothing stored")
        let payload = Data(marker.utf8)
        expect((try? file.write(payload)) != nil, "writes")
        expect((try? file.write(payload)) != nil, "writes again")
        expect(listing(root) == ["store.enc"], "no temporary file is left behind")
        expect(!containsMarker(root), "the marker never reaches the disk in the clear")
        let mode = (try? FileManager.default.attributesOfItem(atPath: file.url.path))?[.posixPermissions]
        expect((mode as? NSNumber)?.intValue == 0o600, "the file is readable by its owner alone")
        expect(failure { _ = try makeFile(root).read() } == .keyMissing, "another key cannot open it")
        expect(read(file) == payload, "its own key reads it back")
    }

    static func refusesAMissingKeyOrACorruptFile() {
        let root = makeRoot()
        let account = newAccount()
        let original = makeFile(root, account: account)
        _ = try? original.write(Data(marker.utf8))
        guard let sealed = try? Data(contentsOf: original.url) else {
            return expect(false, "sealed file exists")
        }
        var corrupted = sealed
        corrupted[corrupted.count - 3] ^= 0x10
        try? corrupted.write(to: original.url)
        let reader = makeFile(root, account: account)
        expect(failure { _ = try reader.read() } == .corrupted(.authentication), "tampering is detected")
        expect(failure { try reader.write(Data("new".utf8)) } == .blocked, "and blocks every write")
        expect((try? Data(contentsOf: original.url)) == corrupted, "the file is left as it was")

        try? sealed.write(to: original.url)
        try? keychain.removeSecret(for: account)
        let keyless = makeFile(root, account: account)
        expect(failure { _ = try keyless.read() } == .keyMissing, "a lost key is reported, not replaced")
        expect(hasKey(account) == false, "no new key was created")
        expect(failure { try keyless.write(Data("new".utf8)) } == .blocked, "and nothing overwrites it")
        expect(failure { try makeFile(root, account: account).write(Data("x".utf8)) } == .keyMissing,
            "even a fresh handle refuses to reseal under a new key")
        expect((try? Data(contentsOf: original.url)) == sealed, "the sealed file survives untouched")
        let restoredKey = makeFile(root, account: account)
        _ = try? restoredKey.erase()
        try? sealed.write(to: original.url)
        expect(failure { try keyless.write(Data("x".utf8)) } == .blocked, "still blocked until a read works")
        try? FileManager.default.removeItem(at: original.url)
        expect(read(keyless) == .some(nil), "a read that works again lifts the block")
        expect(failure { try keyless.write(Data("x".utf8)) } == nil, "and writes resume")
    }

    static func migratesLegacyFilesOnce() {
        let root = makeRoot()
        let legacyURL = root.appendingPathComponent("store.json")
        let legacy = Data("[\"\(marker)\"]".utf8)
        try? legacy.write(to: legacyURL)
        let account = newAccount()
        let file = makeFile(root, legacy: "store.json", account: account)
        expect(read(file) == legacy, "the legacy content is read")
        expect(listing(root) == ["store.enc"], "the plain file is gone once the sealed one verifies")
        expect(!containsMarker(root), "nothing readable is left on disk")
        let again = makeFile(root, legacy: "store.json", account: account)
        expect(read(again) == legacy, "a second run is a no-op")
        expect(listing(root) == ["store.enc"], "and creates no copy")
    }

    static func keepsTheNewerCopyWhenBothExist() {
        let root = makeRoot()
        let account = newAccount()
        let legacyURL = root.appendingPathComponent("store.json")
        let file = makeFile(root, legacy: "store.json", account: account)
        _ = try? file.write(Data("sealed".utf8))
        try? Data("older plain".utf8).write(to: legacyURL)
        let past = Date(timeIntervalSinceNow: -3600)
        try? FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: legacyURL.path)
        expect(read(makeFile(root, legacy: "store.json", account: account)) == Data("sealed".utf8),
            "a valid sealed file is never overwritten by an older plain copy")
        expect(listing(root) == ["store.enc"], "the older plain copy is removed")
        try? Data("newer plain".utf8).write(to: legacyURL)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: 3600)], ofItemAtPath: legacyURL.path)
        expect(read(makeFile(root, legacy: "store.json", account: account)) == Data("newer plain".utf8),
            "a plain copy written since, by the official build, is sealed in")
        expect(listing(root) == ["store.enc"], "and removed")
    }

    static func erasesOneStoreAndItsKeyOnly() {
        let root = makeRoot()
        let historyAccount = newAccount()
        let calculatorAccount = newAccount()
        let history = SealedFile(
            name: "history.enc", account: historyAccount, directory: root, keychain: keychain)
        let calculator = SealedFile(
            name: "calculator.enc", account: calculatorAccount, directory: root, keychain: keychain)
        _ = try? history.write(Data("h".utf8))
        _ = try? calculator.write(Data("c".utf8))
        let oldCopy = try? Data(contentsOf: history.url)
        expect((try? history.erase()) != nil, "erasing succeeds")
        expect(!FileManager.default.fileExists(atPath: history.url.path), "the file is deleted")
        expect(hasKey(historyAccount) == false, "its key is deleted")
        expect(read(calculator) == Data("c".utf8), "another store still opens with its own key")
        if let oldCopy {
            try? oldCopy.write(to: history.url)
            expect(failure { _ = try history.read() } == .keyMissing, "a copy kept elsewhere is now useless")
            try? FileManager.default.removeItem(at: history.url)
        }
        expect((try? history.erase()) != nil, "erasing again is harmless")
        expect((try? history.write(Data("fresh".utf8))) != nil, "a new key starts afresh after erase")
    }

    static func boundsTheFileSize() {
        let root = makeRoot()
        let file = makeFile(root)
        let huge = root.appendingPathComponent("store.enc")
        FileManager.default.createFile(atPath: huge.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: huge) {
            try? handle.truncate(atOffset: UInt64(SealedFile.sizeLimit + 1))
            try? handle.close()
        }
        expect(failure { _ = try file.read() } == .tooLarge, "an oversized file is refused unread")
    }

    static func reportsAFailedWrite() {
        let root = makeRoot()
        let file = makeFile(root)
        try? FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)
        if case .io = failure({ try file.write(Data(marker.utf8)) }) {
            expect(true, "a read-only folder fails the write")
        } else {
            expect(false, "a read-only folder fails the write")
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        expect(listing(root).isEmpty, "and leaves no partial or plain file")
    }

    static func failure(_ body: () throws -> Void) -> SealedFile.Failure? {
        do {
            try body()
            return nil
        } catch let failure as SealedFile.Failure {
            return failure
        } catch {
            return .io(-1)
        }
    }

    // MARK: - The three stores

    static func sealsTheLauncherHistory() {
        let root = makeRoot()
        let file = SealedFile(
            name: "command-input-history.enc", account: newAccount(), directory: root, keychain: keychain)
        var history = LauncherHistory()
        history.record(marker, at: Date())
        expect((try? file.write(history.encoded())) != nil, "the history writes")
        expect(!containsMarker(root), "no entry is readable on disk")
        let reread = read(file).flatMap { $0 }.flatMap { try? LauncherHistory.decoded(from: $0) }
        expect(reread == history, "and it comes back intact after a restart")
    }

    static func sealsTheRankingTable() async {
        let root = makeRoot()
        let file = SealedFile(
            name: "launcher-ranking.enc", legacyName: "launcher-ranking.json", account: newAccount(),
            directory: root, keychain: keychain)
        let legacy = ["app:/Applications/Safari.app": LauncherVisit(
            anchor: Date(timeIntervalSinceNow: 86_400), openedAt: Date(), searchTerms: ["synthetic"])]
        try? JSONEncoder().encode(legacy).write(to: root.appendingPathComponent("launcher-ranking.json"))
        let unused = root.appendingPathComponent("unused.json")
        let store = LauncherRankingStore(fileURL: unused, persistence: file.loadAndSave)
        expect(store.visits.first?.value.searchTerms == ["synthetic"], "learned terms migrate in")
        store.visit(itemKey: "app:/Applications/Notes.app", query: marker)
        await store.flush()
        expect(listing(root) == ["launcher-ranking.enc"], "only the sealed table is on disk")
        expect(!containsMarker(root), "learned search terms are not readable on disk")
        let reloaded = LauncherRankingStore(fileURL: unused, persistence: file.loadAndSave)
        let terms = reloaded.visits["app:/Applications/Notes.app"]?.searchTerms ?? []
        expect(terms == [LauncherRankingStore.normalize(marker)], "and ranking still learns from them")
    }

    static func sealsCalculatorHistory() {
        let root = makeRoot()
        let file = SealedFile(
            name: "calculator-history.enc", legacyName: "calculator-history.json", account: newAccount(),
            directory: root, keychain: keychain)
        let legacy = [CalcHistoryEntry(id: UUID(), expression: "1,5 * 2", result: "3", createdAt: Date())]
        try? JSONEncoder().encode(legacy).write(to: root.appendingPathComponent("calculator-history.json"))
        let store = CalculatorHistoryStore(file: file)
        expect(store.entries.map(\.expression) == ["1,5 * 2"], "past calculations migrate in")
        store.record(expression: "\(marker) + 1", result: "42")
        expect(listing(root) == ["calculator-history.enc"], "only the sealed history is on disk")
        expect(!containsMarker(root), "expressions are not readable on disk")
        expect(CalculatorHistoryStore(file: file).entries.count == 2, "and they reload")
    }

    static func cleanUp() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        for account in accounts { try? keychain.removeSecret(for: account) }
    }
}
