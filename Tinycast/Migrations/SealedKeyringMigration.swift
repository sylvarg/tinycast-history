import Foundation

/// The sealed files' keyring, still under the bundle id `BundleIdentifierMigration` moves from.
enum SealedKeyringMigration {
    private static let currentPrefix = "com.abueammar.tinycast"
    private static let legacyPrefix = "com.tinycast.app"

    static let legacyKeychain: KeychainSecretStore? = Bundle.main.bundleIdentifier
        .flatMap(legacyIdentifier(of:))
        .map { KeychainSecretStore(scope: KeychainSecretStore.sealedStorageScope, bundleIdentifier: $0) }

    static func legacyIdentifier(of bundleID: String) -> String? {
        guard bundleID == currentPrefix || bundleID.hasPrefix(currentPrefix + ".") else { return nil }
        return legacyPrefix + bundleID.dropFirst(currentPrefix.count)
    }

    /// Copied before the old item goes, so a failure in between leaves a key rather than none.
    static func move(
        _ account: UUID, from legacy: KeychainSecretStore, to current: KeychainSecretStore
    ) throws -> String? {
        guard let stored = try legacy.secret(for: account) else { return nil }
        try current.setSecret(stored, for: account)
        try? legacy.removeSecret(for: account)
        return stored
    }
}
