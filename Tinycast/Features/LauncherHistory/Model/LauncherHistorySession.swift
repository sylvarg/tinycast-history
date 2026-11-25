import Foundation

/// The history's rules as a value: each event returns the texts to record, and touches nothing.
struct LauncherHistorySession: Equatable {
    /// Who put the current query in the field.
    enum Origin: Equatable {
        case typed
        /// ↑ wrote it from the history; showing its results again records nothing.
        case recalled
        /// An action rewrote it, as ⌘↵ does with an answer; it was never typed.
        case rewritten
    }

    /// A walk through a snapshot taken on the first ↑, so a write meanwhile cannot shift it.
    struct Recall: Equatable {
        let texts: [String]
        var index: Int

        var current: String { texts[index] }
    }

    enum UpArrow: Equatable {
        /// Not a history key here: the launcher navigates its rows as it always has.
        case ignore
        /// Put this text in the field.
        case write(String)
        /// Already at the oldest entry: the key is consumed and nothing loops.
        case stay
    }

    /// Long enough that a result flashing past mid-typing is not taken for one the user read.
    static let presentationDwell: TimeInterval = 0.7

    private(set) var query = ""
    private(set) var origin = Origin.typed
    private(set) var recall: Recall?
    /// A result shown for typed text, recorded once read or once the palette leaves with it.
    private(set) var shown: Shown?
    /// The query whose result was already recorded, so showing it again is not a second event.
    private(set) var settled: String?
    /// The rewrite token last drawn; a new one means an action, not a keystroke, wrote the field.
    private var seenRewriteToken: UUID?

    struct Shown: Equatable {
        let text: String
        let since: Date
    }

    /// Recall starts only from a strictly empty field, and continues only while ↑ wrote the text.
    mutating func upArrow(query current: String, history: [String]) -> UpArrow {
        if current.isEmpty {
            guard !history.isEmpty else { return .ignore }
            recall = Recall(texts: history, index: 0)
            return .write(history[0])
        }
        guard var recall, origin == .recalled, current == recall.current else { return .ignore }
        guard recall.index + 1 < recall.texts.count else { return .stay }
        recall.index += 1
        self.recall = recall
        return .write(recall.current)
    }

    /// The field as drawn, with `PaletteState.queryRewriteToken`, which an action's rewrite bumps.
    mutating func observe(
        query text: String, rewriteToken: UUID, resultShown: Bool, at now: Date
    ) -> [String] {
        // The compact bar mounts the list only once ↑ has filled the field, so no token was seen.
        let rewritten = seenRewriteToken.map { $0 != rewriteToken } ?? (recall?.current == text)
        seenRewriteToken = rewriteToken
        return observe(query: text, rewritten: rewritten, resultShown: resultShown, at: now)
    }

    /// The field changed. `rewritten` says an action wrote it rather than a keystroke.
    mutating func observe(
        query text: String, rewritten: Bool, resultShown: Bool, at now: Date
    ) -> [String] {
        var recorded: [String] = []
        if text != query {
            recorded += settleShown(at: now, requiringDwell: true)
            if rewritten, let recall, text == recall.current {
                origin = .recalled
            } else {
                recall = nil
                origin = rewritten ? .rewritten : .typed
            }
            query = text
            settled = nil
        }
        if resultShown, origin == .typed, settled != text, LauncherHistory.isRecordable(text) {
            if shown?.text != text { shown = Shown(text: text, since: now) }
        } else if shown != nil {
            recorded += settleShown(at: now, requiringDwell: true)
        }
        return recorded
    }

    /// The launcher left: a hidden palette had its result read, a swapped screen may not have.
    mutating func left(at now: Date, paletteHidden: Bool) -> [String] {
        recall = nil
        seenRewriteToken = nil
        return settleShown(at: now, requiringDwell: !paletteHidden)
    }

    /// An action was taken on the current query: the text it validates, or nil when there is none.
    mutating func validate() -> String? {
        guard origin != .rewritten, LauncherHistory.isRecordable(query) else { return nil }
        // The result on screen and the action on it are one event, recorded once.
        if shown?.text == query { shown = nil }
        settled = query
        return query
    }

    /// Locking the session forgets the walk and anything not yet recorded.
    mutating func reset() {
        self = LauncherHistorySession()
    }

    private mutating func settleShown(at now: Date, requiringDwell: Bool) -> [String] {
        guard let shown else { return [] }
        self.shown = nil
        guard !requiringDwell || now.timeIntervalSince(shown.since) >= Self.presentationDwell else {
            return []
        }
        settled = shown.text
        return [shown.text]
    }
}

/// The last validation, held a moment so a refused confirmation or a missing argument can undo it.
struct LauncherHistoryUndo: Equatable {
    /// An action's own dialog opens within moments; one later belongs to something else.
    static let confirmationWindow: TimeInterval = 2

    private(set) var pending: Pending?

    struct Pending: Equatable {
        let before: LauncherHistory
        var after: LauncherHistory
        var at: Date
        var awaitingConfirmation = false
    }

    /// Validations of one gesture (a menu row, then the launch it runs) undo together.
    mutating func recorded(before: LauncherHistory, after: LauncherHistory, at now: Date) {
        if var pending, pending.after == before,
            now.timeIntervalSince(pending.at) <= Self.confirmationWindow
        {
            pending.after = after
            pending.at = now
            self.pending = pending
        } else {
            pending = Pending(before: before, after: after, at: now)
        }
    }

    mutating func confirmationBegan(at now: Date) {
        guard var pending, !pending.awaitingConfirmation,
            now.timeIntervalSince(pending.at) <= Self.confirmationWindow
        else {
            if pending?.awaitingConfirmation == false { pending = nil }
            return
        }
        pending.awaitingConfirmation = true
        self.pending = pending
    }

    /// The history to restore when the awaited confirmation was refused, if nothing moved since.
    mutating func confirmationEnded(accepted: Bool, current: LauncherHistory) -> LauncherHistory? {
        guard let pending, pending.awaitingConfirmation else { return nil }
        self.pending = nil
        return !accepted && current == pending.after ? pending.before : nil
    }

    /// The launch asked for its arguments instead of running.
    mutating func withdraw(current: LauncherHistory, at now: Date) -> LauncherHistory? {
        guard let pending, now.timeIntervalSince(pending.at) <= Self.confirmationWindow else { return nil }
        self.pending = nil
        return current == pending.after ? pending.before : nil
    }

    mutating func clear() {
        pending = nil
    }
}
