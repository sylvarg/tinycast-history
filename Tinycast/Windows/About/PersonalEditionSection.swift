import SwiftUI

/// The personal edition in About: what it adds, the official release it rebuilds, where it lives.
struct PersonalEditionSection: View {
    static let repository = URL(string: "https://github.com/sylvarg/tinycast-history")!
    static let upstream = URL(string: "https://github.com/abue-ammar/tinycast")!

    private static let version: AppVersion? = {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return short.flatMap(AppVersion.init)
    }()

    var body: some View {
        Section {
            LabeledContent(text("Edition"), value: text("Personal edition with history"))
            LabeledContent(
                text("Official base version"),
                value: Self.version.map { "\($0.major).\($0.minor).\($0.patch)" } ?? "—")
            LabeledContent(
                text("Personal revision"), value: Self.version?.revision.map { "h.\($0)" } ?? "—")
            Link(text("Source code and releases"), destination: Self.repository)
            Link(
                text("Report a problem with this edition"),
                destination: Self.repository.appending(path: "issues"))
            Link(text("Original project by Abue Ammar"), destination: Self.upstream)
        } header: {
            Text(text("Personal edition with history"))
        }
    }

    private func text(_ key: String.LocalizationValue) -> String {
        String(localized: key, table: "PersonalEdition")
    }
}
