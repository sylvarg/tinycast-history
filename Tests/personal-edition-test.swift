import Foundation

/// The edition's release identity: `-h.N` revisions, our feed, and what is offered as an update.
@main
struct PersonalEditionTests {
    nonisolated(unsafe) static var failures = 0
    nonisolated(unsafe) static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        parsesRevisions()
        ordersRevisionsBetweenOfficialReleases()
        offersRevisionsFromThisRepository()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func version(_ text: String) -> AppVersion {
        guard let parsed = AppVersion(text) else { fatalError("\(text) must parse") }
        return parsed
    }

    static func parsesRevisions() {
        expect(AppVersion("0.12.1-h.1")?.revision == 1, "reads the personal revision")
        expect(AppVersion("v0.12.1-h.12")?.description == "0.12.1-h.12", "round-trips a revision tag")
        expect(AppVersion("0.12.1-h.3")?.isPrerelease == false, "a revision is a stable release")
        expect(AppVersion("0.12.1-h.3")?.beta == nil, "and carries no beta counter")
        expect(AppVersion("0.12.1-h") == nil, "rejects a revision without a number")
        expect(AppVersion("0.12.1-h.x") == nil, "rejects a non-numeric revision")
        expect(AppVersion("0.12.1-h.-1") == nil, "rejects a signed revision")
        expect(AppVersion("0.12.1-p.1") == nil, "still rejects channels that never ship")
        expect(AppVersion("0.2.0-beta.42")?.beta == 42, "upstream's betas still parse")
    }

    static func ordersRevisionsBetweenOfficialReleases() {
        expect(version("0.12.1-h.1") > version("0.12.1"), "a revision outranks the release it rebuilds")
        expect(version("0.12.1-h.2") > version("0.12.1-h.1"), "a correction outranks the revision before")
        expect(version("0.12.1-h.10") > version("0.12.1-h.9"), "revisions compare numerically")
        expect(version("0.12.2") > version("0.12.1-h.9"), "the next official release outranks them")
        expect(version("0.12.2-h.1") > version("0.12.2"), "and its own first revision outranks it")
        expect(version("0.13.0-beta.1") > version("0.12.2-h.4"), "a newer triple still wins")
        expect(version("0.12.1-h.1") != version("0.12.1"), "a revision is never equal to the release")
        expect(version("0.12.1-h.0") == version("0.12.1-h.0"), "equal revisions are equal")
    }

    static func feed(_ tags: [(String, Bool)]) -> Data {
        let releases = tags.map { tag, prerelease in
            """
            {"tag_name": "\(tag)", "prerelease": \(prerelease), "draft": false, "body": "notes",
             "published_at": "2026-10-24T00:00:00Z",
             "assets": [{"name": "Tinycast-\(tag.dropFirst()).zip", "size": 10,
                         "browser_download_url": "https://example.invalid/\(tag)/Tinycast.zip"},
                        {"name": "Tinycast-\(tag.dropFirst()).dmg", "size": 10,
                         "browser_download_url": "https://example.invalid/x.dmg"}]}
            """
        }
        return Data("[\(releases.joined(separator: ","))]".utf8)
    }

    static func offersRevisionsFromThisRepository() {
        expect(ReleaseFeed.repository == "sylvarg/tinycast-history", "updates come from this repository")
        let data = feed([("v0.12.1-h.1", false), ("v0.12.1-h.2", false), ("v0.12.2-beta.1", true)])
        let newest = ReleaseFeed.newest(from: data, channel: .stable, architecture: .appleSilicon)
        expect(newest?.tag == "v0.12.1-h.2", "the stable channel takes the newest revision, never a beta")
        expect(newest?.assetURL.lastPathComponent == "Tinycast.zip", "and installs the zip, not the DMG")
        let offered = { (running: String) in
            ReleaseFeed.offer(newest, running: version(running), skipped: nil)?.tag
        }
        expect(offered("0.12.1-h.1") == "v0.12.1-h.2", "a correction is offered over the revision before")
        expect(offered("0.12.1") == "v0.12.1-h.2", "the official build is offered this edition's revision")
        expect(offered("0.12.1-h.2") == nil, "nothing is offered to the newest revision")
        expect(offered("0.12.2") == nil, "an older base is never offered over a newer one")
        let mislabelled = feed([("v0.12.1-h.3", true)])
        expect(
            ReleaseFeed.newest(from: mislabelled, channel: .stable, architecture: .appleSilicon) == nil,
            "a revision published as a prerelease is skipped as mis-published")
        expect(ReleaseChannel(bundleID: "com.tinycast.app") == .stable, "the edition keeps the stable id")
    }
}
