import CryptoKit
import Darwin
import Foundation
import Synchronization

/// A file that only reaches disk sealed under its own Keychain key; a failed read blocks writes.
final class SealedFile: Sendable {
    enum Failure: Error, Equatable {
        /// The file exists but its key is gone; a new key would make it unreadable for good.
        case keyMissing
        case keychain(OSStatus)
        case corrupted(SealedEnvelope.Failure)
        case tooLarge
        case io(Int32)
        case migrationMismatch
        /// A read failed earlier this session, so writing could overwrite what it holds.
        case blocked
    }

    /// The Keychain accounts, one per sealed file, so erasing one key leaves the others readable.
    enum Account {
        static let launcherHistory = UUID(uuidString: "6B2F4E1A-0C7D-4B53-9E58-2D4A61C3F0A1")!
        static let calculatorHistory = UUID(uuidString: "C1E5A7D2-3F84-4E09-A6B1-7D0F2C95E4B3")!
        static let launcherRanking = UUID(uuidString: "4A9D0B63-E2C1-47F8-8B5E-91C3D6A70F2E")!
    }

    static let launcherHistory = SealedFile(
        name: "command-input-history.enc", account: Account.launcherHistory)
    static let calculatorHistory = SealedFile(
        name: "calculator-history.enc", legacyName: "calculator-history.json",
        account: Account.calculatorHistory)
    static let launcherRanking = SealedFile(
        name: "launcher-ranking.enc", legacyName: "launcher-ranking.json",
        account: Account.launcherRanking)

    /// Posted with the file name when a read or write fails; the coordinator turns it into a HUD.
    static let didFailNotification = Notification.Name("SealedFileDidFail")
    static let sizeLimit = 16 * 1024 * 1024

    let url: URL
    private let legacyURL: URL?
    private let purpose: String
    private let account: UUID
    private let keychain: KeychainSecretStore
    private let isBlocked = Mutex(false)

    init(
        name: String, legacyName: String? = nil, account: UUID,
        directory: URL = AppPaths.applicationSupport(),
        keychain: KeychainSecretStore = .sealedStorageKeys
    ) {
        url = directory.appendingPathComponent(name, isDirectory: false)
        legacyURL = legacyName.map { directory.appendingPathComponent($0, isDirectory: false) }
        purpose = name
        self.account = account
        self.keychain = keychain
    }

    var blocked: Bool { isBlocked.withLock { $0 } }

    /// The plaintext, or nil when nothing was ever stored. A legacy plain file is sealed first.
    func read() throws(Failure) -> Data? {
        do {
            let plaintext = try readOrMigrate()
            isBlocked.withLock { $0 = false }
            return plaintext
        } catch {
            isBlocked.withLock { $0 = true }
            report()
            throw error
        }
    }

    func write(_ plaintext: Data) throws(Failure) {
        guard !blocked else { throw .blocked }
        do {
            try seal(plaintext)
        } catch {
            report()
            throw error
        }
    }

    /// Deletes the file and its key, so a copy of it left anywhere can no longer be opened.
    func erase() throws(Failure) {
        for target in [url, legacyURL].compactMap(\.self) {
            guard unlink(target.path) == 0 || errno == ENOENT else { throw .io(errno) }
        }
        do {
            try keychain.removeSecret(for: account)
        } catch let KeychainSecretStore.StoreError.keychain(status) {
            throw .keychain(status)
        } catch {
            throw .keychain(errSecParam)
        }
        isBlocked.withLock { $0 = false }
    }

    private func readOrMigrate() throws(Failure) -> Data? {
        let sealed = try contents(of: url)
        guard let legacyURL, let legacy = try contents(of: legacyURL) else {
            guard let sealed else { return nil }
            return try open(sealed)
        }
        // Both exist after a crash mid-migration or a return to the official build: newer wins.
        if let sealed, modificationDate(url) >= modificationDate(legacyURL) {
            let plaintext = try open(sealed)
            try remove(legacyURL)
            return plaintext
        }
        try seal(legacy)
        guard let resealed = try contents(of: url), try open(resealed) == legacy else {
            throw .migrationMismatch
        }
        try remove(legacyURL)
        return legacy
    }

    private func open(_ envelope: Data) throws(Failure) -> Data {
        guard let key = try existingKey() else { throw .keyMissing }
        do {
            return try SealedEnvelope.open(envelope, key: key, purpose: purpose)
        } catch {
            throw .corrupted(error)
        }
    }

    private func seal(_ plaintext: Data) throws(Failure) {
        let key: SymmetricKey
        if let existing = try existingKey() {
            key = existing
        } else if FileManager.default.fileExists(atPath: url.path) {
            throw .keyMissing
        } else {
            key = try createKey()
        }
        let envelope: Data
        do {
            envelope = try SealedEnvelope.seal(plaintext, key: key, purpose: purpose)
        } catch {
            throw .corrupted(.unknownFormat)
        }
        try replaceAtomically(with: envelope)
    }

    /// A private temporary beside the file, renamed over it: only sealed bytes are written.
    private func replaceAtomically(with envelope: Data) throws(Failure) {
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        let descriptor = Darwin.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw .io(errno) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: envelope)
            try handle.synchronize()
            try handle.close()
        } catch {
            unlink(temporary.path)
            throw .io(EIO)
        }
        guard rename(temporary.path, url.path) == 0 else {
            let code = errno
            unlink(temporary.path)
            throw .io(code)
        }
    }

    private func contents(of file: URL) throws(Failure) -> Data? {
        var status = stat()
        guard stat(file.path, &status) == 0 else {
            if errno == ENOENT { return nil }
            throw .io(errno)
        }
        guard status.st_size <= off_t(Self.sizeLimit) else { throw .tooLarge }
        do {
            return try Data(contentsOf: file)
        } catch {
            throw .io(EIO)
        }
    }

    private func remove(_ file: URL) throws(Failure) {
        guard unlink(file.path) == 0 || errno == ENOENT else { throw .io(errno) }
    }

    private func modificationDate(_ file: URL) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        return attributes?[.modificationDate] as? Date ?? .distantPast
    }

    private func existingKey() throws(Failure) -> SymmetricKey? {
        let encoded: String?
        do {
            encoded = try keychain.secret(for: account)
        } catch let KeychainSecretStore.StoreError.keychain(status) {
            throw .keychain(status)
        } catch {
            throw .keychain(errSecDecode)
        }
        guard let encoded else { return nil }
        guard let bytes = Data(base64Encoded: encoded), bytes.count == 32 else {
            throw .keychain(errSecDecode)
        }
        return SymmetricKey(data: bytes)
    }

    private func createKey() throws(Failure) -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let encoded = key.withUnsafeBytes { Data($0).base64EncodedString() }
        do {
            try keychain.setSecret(encoded, for: account)
        } catch let KeychainSecretStore.StoreError.keychain(status) {
            throw .keychain(status)
        } catch {
            throw .keychain(errSecParam)
        }
        return key
    }

    /// The shape `LauncherRankingStore` persists through, so its harnesses never see this type.
    var loadAndSave: (load: @Sendable () -> Data?, save: @Sendable (Data) -> Void) {
        (load: { try? self.read() }, save: { try? self.write($0) })
    }

    private func report() {
        let name = url.lastPathComponent
        Task { @MainActor in
            NotificationCenter.default.post(name: Self.didFailNotification, object: name)
        }
    }
}
