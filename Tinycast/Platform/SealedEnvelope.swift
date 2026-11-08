import CryptoKit
import Foundation

/// AES-256-GCM behind a versioned header; header and purpose are authenticated, never trusted.
enum SealedEnvelope {
    enum Failure: Error, Equatable {
        case truncated
        case unknownFormat
        case unsupportedVersion
        case authentication
    }

    static let magic = Data("TCSE".utf8)
    static let version: UInt8 = 1
    /// A random 96-bit nonce and a 128-bit tag, as `AES.GCM.SealedBox.combined` lays them out.
    private static let boxOverhead = 12 + 16

    private static var header: Data { magic + [version] }

    static func seal(_ plaintext: Data, key: SymmetricKey, purpose: String) throws -> Data {
        let box = try AES.GCM.seal(
            plaintext, using: key, nonce: AES.GCM.Nonce(),
            authenticating: associatedData(purpose: purpose))
        guard let combined = box.combined else { throw Failure.unknownFormat }
        return header + combined
    }

    static func open(_ envelope: Data, key: SymmetricKey, purpose: String) throws(Failure) -> Data {
        let header = header
        guard envelope.count >= header.count + boxOverhead else { throw .truncated }
        guard envelope.prefix(magic.count) == magic else { throw .unknownFormat }
        guard envelope[envelope.startIndex + magic.count] == version else { throw .unsupportedVersion }
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.dropFirst(header.count))
            return try AES.GCM.open(box, using: key, authenticating: associatedData(purpose: purpose))
        } catch {
            throw .authentication
        }
    }

    private static func associatedData(purpose: String) -> Data {
        header + Data("tinycast-sealed-file:\(purpose)".utf8)
    }
}
