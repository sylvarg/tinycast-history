import Foundation

/// One validated launcher query, exactly as it was typed.
struct LauncherHistoryEntry: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let text: String
    var lastValidatedAt: Date
}

/// The launcher's validated queries, newest first, each text at most once.
struct LauncherHistory: Codable, Equatable, Sendable {
    static let capacity = 100

    private(set) var entries: [LauncherHistoryEntry]

    init(entries: [LauncherHistoryEntry] = []) {
        self.entries = Array(entries.prefix(Self.capacity))
    }

    var texts: [String] { entries.map(\.text) }

    /// A text validated before moves to the front with its id; false when there is nothing to keep.
    @discardableResult
    mutating func record(_ text: String, at date: Date, makeID: () -> UUID = UUID.init) -> Bool {
        guard Self.isRecordable(text) else { return false }
        if let index = entries.firstIndex(where: { $0.text == text }) {
            var entry = entries.remove(at: index)
            entry.lastValidatedAt = date
            entries.insert(entry, at: 0)
        } else {
            entries.insert(LauncherHistoryEntry(id: makeID(), text: text, lastValidatedAt: date), at: 0)
            if entries.count > Self.capacity { entries.removeLast(entries.count - Self.capacity) }
        }
        return true
    }

    /// Only emptiness is judged on a trimmed copy; the stored text keeps every space it had.
    static func isRecordable(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decoded(from data: Data) throws -> LauncherHistory {
        try JSONDecoder().decode(LauncherHistory.self, from: data)
    }
}
