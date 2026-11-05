import Foundation

/// Signed by `.personal/tests/signing.sh` to answer as the app would: bundle trust, Keychain.
@main
struct PersonalSignatureProbe {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else { fail("usage: trust <bundle> | keychain <write|read> <dir>") }
        switch (arguments[1], arguments[2]) {
        case ("trust", let path):
            print(BundleSignature.isTrusted(URL(fileURLWithPath: path)) ? "trusted" : "refused")
        case ("keychain", let mode) where arguments.count == 4:
            let file = SealedFile(
                name: "probe.enc", account: UUID(uuidString: "0B5E0A6E-1C2D-4E3F-8A9B-0C1D2E3F4A5B")!,
                directory: URL(fileURLWithPath: arguments[3]),
                keychain: KeychainSecretStore(scope: "probe", bundleIdentifier: "com.tinycast.probe"))
            do {
                if mode == "write" {
                    try file.write(Data("probe-secret".utf8))
                    print("written")
                } else if mode == "erase" {
                    try file.erase()
                    print("erased")
                } else {
                    let data = try file.read()
                    print(data.map { String(bytes: $0, encoding: .utf8) ?? "?" } ?? "absent")
                }
            } catch {
                fail("failed: \(error)")
            }
        default:
            fail("unknown command")
        }
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
