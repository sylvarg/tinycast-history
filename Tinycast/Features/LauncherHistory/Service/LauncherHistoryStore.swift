import Foundation

/// The sealed `command-input-history.enc`, loaded on first use and dropped again on lock.
@MainActor
final class LauncherHistoryStore {
    enum State: Equatable {
        case unloaded
        case loaded(LauncherHistory)
        case unavailable(SealedFile.Failure)
    }

    private let file: SealedFile
    private(set) var state = State.unloaded

    init(file: SealedFile = .launcherHistory) {
        self.file = file
    }

    var isUnavailable: Bool {
        if case .unavailable = state { return true }
        return false
    }

    /// Nil while the file or its key cannot be read; nothing is written over it until it can.
    func history() -> LauncherHistory? {
        if case .unloaded = state { load() }
        guard case .loaded(let history) = state else { return nil }
        return history
    }

    @discardableResult
    func save(_ history: LauncherHistory) -> Bool {
        guard case .loaded = state else { return false }
        do {
            try file.write(history.encoded())
        } catch let failure as SealedFile.Failure {
            state = .unavailable(failure)
            return false
        } catch {
            state = .unavailable(.corrupted(.unknownFormat))
            return false
        }
        state = .loaded(history)
        return true
    }

    /// Forgets the decrypted entries; the next use reads the file again.
    func release() {
        state = .unloaded
    }

    func erase() throws {
        try file.erase()
        state = .loaded(LauncherHistory())
    }

    private func load() {
        do {
            let data = try file.read()
            state = .loaded(try data.map(LauncherHistory.decoded) ?? LauncherHistory())
        } catch let failure as SealedFile.Failure {
            state = .unavailable(failure)
        } catch {
            state = .unavailable(.corrupted(.unknownFormat))
        }
    }
}
