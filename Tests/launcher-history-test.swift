import Foundation

/// The launcher history's rules, driven through the shipped model: recording, recall, display.
@main
struct LauncherHistoryTests {
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

    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    static func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    static func main() {
        recordsInOrder()
        capsAtCapacity()
        movesARepeatInsteadOfDuplicating()
        keepsTextAsTyped()
        roundTripsThroughJSON()
        recallsFromAnEmptyField()
        neverRecallsFromTypedText()
        editingEndsTheWalk()
        recallDoesNotRecord()
        promotesARecalledEntryOnValidation()
        recordsAShownResultOnceRead()
        recordsAShownResultWhenThePaletteHides()
        ignoresIntermediateAndUnusableResults()
        validationAndDisplayAreOneEvent()
        ignoresTextAnActionWrote()
        undoesARefusedConfirmation()
        undoesALaunchThatAskedForArguments()
        tellsRewritesFromKeystrokesByToken()
        forgetsEverythingOnLock()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    // MARK: - LauncherHistory

    static func recordsInOrder() {
        var history = LauncherHistory()
        expect(history.entries.isEmpty, "a new history is empty")
        expect(history.record("saf", at: at(0)), "records a typed query")
        expect(history.texts == ["saf"], "one entry")
        history.record("12 * 3", at: at(1))
        history.record("1,5 * 2", at: at(2))
        expect(history.texts == ["1,5 * 2", "12 * 3", "saf"], "newest first")
        expect(!history.record("", at: at(3)), "an empty string is not recorded")
        expect(!history.record("  \n\t ", at: at(3)), "whitespace alone is not recorded")
        expect(history.entries.count == 3, "blank input left the history unchanged")
    }

    static func capsAtCapacity() {
        var history = LauncherHistory()
        for index in 0..<(LauncherHistory.capacity + 25) {
            history.record("q\(index)", at: at(Double(index)))
        }
        expect(LauncherHistory.capacity == 100, "the history keeps one hundred entries")
        expect(history.entries.count == LauncherHistory.capacity, "never more than the capacity")
        expect(history.texts.first == "q124", "the newest survives")
        expect(history.texts.last == "q25", "the oldest beyond the capacity are dropped")
        let decoded = LauncherHistory(entries: (0..<150).map {
            LauncherHistoryEntry(id: UUID(), text: "x\($0)", lastValidatedAt: at(0))
        })
        expect(decoded.entries.count == 100, "an oversized list is trimmed on the way in")
    }

    static func movesARepeatInsteadOfDuplicating() {
        var history = LauncherHistory()
        history.record("C", at: at(0))
        history.record("B", at: at(1))
        history.record("A", at: at(2))
        let idOfC = history.entries[2].id
        history.record("A", at: at(3))
        expect(history.texts == ["A", "B", "C"], "validating the newest again adds nothing")
        history.record("C", at: at(4))
        expect(history.texts == ["C", "A", "B"], "an older text moves to the front")
        expect(history.entries.count == 3, "and the count stays the same")
        expect(history.entries[0].id == idOfC, "it keeps its identifier")
        expect(history.entries[0].lastValidatedAt == at(4), "its validation date moves on")
    }

    static func keepsTextAsTyped() {
        var history = LauncherHistory()
        let text = "  Café ☕️ 12,5 € → $  "
        history.record(text, at: at(0))
        expect(history.texts == [text], "spaces and Unicode are kept exactly")
        history.record("12*3", at: at(1))
        history.record("12 * 3", at: at(2))
        expect(history.entries.count == 3, "different spacing is a different input")
    }

    static func roundTripsThroughJSON() {
        var history = LauncherHistory()
        history.record("ŝaf ✓", at: at(0))
        history.record("1,5 * 2", at: at(1))
        let decoded = (try? history.encoded()).flatMap { try? LauncherHistory.decoded(from: $0) }
        expect(decoded == history, "entries, ids and dates survive encoding")
        expect((try? LauncherHistory.decoded(from: Data("{".utf8))) == nil, "garbage does not decode")
    }

    // MARK: - Recall

    static func recallsFromAnEmptyField() {
        var session = LauncherHistorySession()
        let history = ["A", "B", "C"]
        expect(session.upArrow(query: "", history: []) == .ignore, "an empty history leaves ↑ alone")
        expect(session.upArrow(query: "", history: history) == .write("A"), "first ↑ writes the newest")
        _ = session.observe(query: "A", rewritten: true, resultShown: false, at: at(0))
        expect(session.origin == .recalled, "the written text is known as recalled")
        expect(session.upArrow(query: "A", history: history) == .write("B"), "the next ↑ goes older")
        _ = session.observe(query: "B", rewritten: true, resultShown: false, at: at(1))
        expect(session.upArrow(query: "B", history: history) == .write("C"), "and older again")
        _ = session.observe(query: "C", rewritten: true, resultShown: false, at: at(2))
        expect(session.upArrow(query: "C", history: history) == .stay, "the oldest stops, never loops")
        expect(session.upArrow(query: "C", history: history) == .stay, "held ↑ keeps stopping")
        _ = session.observe(query: "C", rewritten: false, resultShown: true, at: at(3))
        expect(session.upArrow(query: "C", history: history) == .stay, "results moving do not end it")
    }

    static func neverRecallsFromTypedText() {
        var session = LauncherHistorySession()
        _ = session.observe(query: "s", rewritten: false, resultShown: false, at: at(0))
        expect(session.upArrow(query: "s", history: ["A"]) == .ignore, "typed text keeps ↑ for rows")
        _ = session.observe(query: " ", rewritten: false, resultShown: false, at: at(1))
        expect(session.upArrow(query: " ", history: ["A"]) == .ignore, "a space is not an empty field")
    }

    static func editingEndsTheWalk() {
        var session = LauncherHistorySession()
        let history = ["A", "B"]
        _ = session.upArrow(query: "", history: history)
        _ = session.observe(query: "A", rewritten: true, resultShown: false, at: at(0))
        _ = session.observe(query: "Ax", rewritten: false, resultShown: false, at: at(1))
        expect(session.recall == nil, "typing ends the walk")
        expect(session.upArrow(query: "Ax", history: history) == .ignore, "↑ is the rows' again")
        _ = session.observe(query: "A", rewritten: false, resultShown: false, at: at(2))
        expect(session.upArrow(query: "A", history: history) == .ignore, "deleting back does not resume")
        _ = session.observe(query: "", rewritten: false, resultShown: false, at: at(3))
        expect(session.upArrow(query: "", history: history) == .write("A"), "emptying it starts afresh")
        _ = session.observe(query: "A", rewritten: true, resultShown: false, at: at(4))
        _ = session.left(at: at(5), paletteHidden: true)
        expect(session.upArrow(query: "A", history: history) == .ignore, "closing ends the walk")
        _ = session.observe(query: "Z", rewritten: true, resultShown: false, at: at(6))
        expect(session.origin == .rewritten, "another rewrite is not a recall")
    }

    static func recallDoesNotRecord() {
        var session = LauncherHistorySession()
        _ = session.upArrow(query: "", history: ["12 * 3"])
        var recorded = session.observe(query: "12 * 3", rewritten: true, resultShown: true, at: at(0))
        recorded += session.observe(query: "12 * 3", rewritten: false, resultShown: true, at: at(5))
        recorded += session.left(at: at(10), paletteHidden: true)
        expect(recorded.isEmpty, "showing a recalled entry's result records nothing")
    }

    static func promotesARecalledEntryOnValidation() {
        var history = LauncherHistory()
        for text in ["C", "B", "A"] { history.record(text, at: at(0)) }
        let idOfC = history.entries[2].id
        var session = LauncherHistorySession()
        for (index, text) in ["A", "B", "C"].enumerated() {
            let step = session.upArrow(query: session.query, history: history.texts)
            expect(step == .write(text), "↑ to \(text)")
            _ = session.observe(query: text, rewritten: true, resultShown: true, at: at(Double(index)))
        }
        expect(history.texts == ["A", "B", "C"], "recalling C leaves the order alone")
        guard let validated = session.validate() else { return expect(false, "validation yields C") }
        history.record(validated, at: at(9))
        expect(history.texts == ["C", "A", "B"], "validating C moves it to the front")
        expect(history.entries.count == 3 && history.entries[0].id == idOfC, "same entry, no copy")
        expect(history.entries[0].lastValidatedAt == at(9), "with a fresh validation date")
    }

    // MARK: - Shown results

    static func recordsAShownResultOnceRead() {
        var session = LauncherHistorySession()
        var recorded = session.observe(query: "12 * 3", rewritten: false, resultShown: true, at: at(0))
        recorded += session.observe(query: "12 * 3", rewritten: false, resultShown: true, at: at(0.2))
        expect(recorded.isEmpty, "nothing yet while the result is on screen")
        recorded += session.observe(query: "12 * 3 +", rewritten: false, resultShown: false, at: at(2))
        expect(recorded == ["12 * 3"], "a result read before the edit is kept")
        recorded = session.observe(query: "1,5 * 2", rewritten: false, resultShown: true, at: at(3))
        recorded += session.observe(query: "", rewritten: false, resultShown: false, at: at(4))
        expect(recorded == ["1,5 * 2"], "the original text is kept, decimal comma included")
    }

    static func recordsAShownResultWhenThePaletteHides() {
        var session = LauncherHistorySession()
        _ = session.observe(query: "time in tokyo", rewritten: false, resultShown: true, at: at(0))
        let recorded = session.left(at: at(0.1), paletteHidden: true)
        expect(recorded == ["time in tokyo"], "Escape or a click away keeps the shown result")
        expect(session.left(at: at(1), paletteHidden: true).isEmpty, "a second hide is not a second event")
        let again = session.observe(query: "time in tokyo", rewritten: false, resultShown: true, at: at(9))
        expect(again.isEmpty && session.shown == nil, "showing the same screen again records nothing")
    }

    static func ignoresIntermediateAndUnusableResults() {
        var session = LauncherHistorySession()
        var recorded = session.observe(query: "12*3", rewritten: false, resultShown: true, at: at(0))
        recorded += session.observe(query: "12*34", rewritten: false, resultShown: true, at: at(0.15))
        expect(recorded.isEmpty, "a result typed straight past is not kept")
        recorded += session.observe(query: "12*345", rewritten: false, resultShown: true, at: at(0.3))
        recorded += session.left(at: at(1), paletteHidden: true)
        expect(recorded == ["12*345"], "only the result left on screen is")
        session = LauncherHistorySession()
        recorded = session.observe(query: "100 usd in", rewritten: false, resultShown: false, at: at(0))
        recorded += session.observe(query: "10 usd in eur", rewritten: false, resultShown: false, at: at(1))
        recorded += session.left(at: at(5), paletteHidden: true)
        expect(recorded.isEmpty, "loading, errors and plain matches are not results")
        recorded = session.observe(query: "10 usd in eur", rewritten: false, resultShown: true, at: at(6))
        recorded += session.left(at: at(7), paletteHidden: false)
        expect(recorded == ["10 usd in eur"], "the result once it arrives is")
        session = LauncherHistorySession()
        recorded = session.observe(query: "2^8", rewritten: false, resultShown: true, at: at(0))
        recorded += session.left(at: at(0.1), paletteHidden: false)
        expect(recorded.isEmpty, "a screen swapped away mid-typing does not count as read")
    }

    static func validationAndDisplayAreOneEvent() {
        var session = LauncherHistorySession()
        var recorded = session.observe(query: "12 * 3", rewritten: false, resultShown: true, at: at(0))
        let validated = session.validate()
        recorded += session.left(at: at(3), paletteHidden: true)
        expect(validated == "12 * 3" && recorded.isEmpty, "copying a shown answer records it once")
        session = LauncherHistorySession()
        _ = session.observe(query: "", rewritten: false, resultShown: false, at: at(0))
        expect(session.validate() == nil, "an action with an empty field records nothing")
        _ = session.observe(query: "saf", rewritten: false, resultShown: false, at: at(1))
        expect(session.validate() == "saf", "opening Safari from `saf` records `saf`")
    }

    static func ignoresTextAnActionWrote() {
        var session = LauncherHistorySession()
        _ = session.observe(query: "12 * 3", rewritten: false, resultShown: true, at: at(0))
        expect(session.validate() == "12 * 3", "⌘↵ validates the expression it chains from")
        var recorded = session.observe(query: "36", rewritten: true, resultShown: true, at: at(0.1))
        recorded += session.left(at: at(5), paletteHidden: true)
        expect(recorded.isEmpty, "the answer it wrote is not a new input")
        expect(session.validate() == nil, "nor is an action on it")
        recorded = session.observe(query: "36 + 4", rewritten: false, resultShown: true, at: at(6))
        recorded += session.left(at: at(8), paletteHidden: true)
        expect(recorded == ["36 + 4"], "but typing onto it is")
    }

    static func tellsRewritesFromKeystrokesByToken() {
        var session = LauncherHistorySession()
        let first = UUID()
        _ = session.observe(query: "", rewriteToken: first, resultShown: false, at: at(0))
        expect(session.upArrow(query: "", history: ["A", "B"]) == .write("A"), "↑ writes A")
        let recallToken = UUID()
        _ = session.observe(query: "A", rewriteToken: recallToken, resultShown: true, at: at(1))
        expect(session.origin == .recalled, "a new token with the written text is the recall")
        _ = session.observe(query: "Ab", rewriteToken: recallToken, resultShown: false, at: at(2))
        expect(session.origin == .typed && session.recall == nil, "the same token is a keystroke")
        _ = session.observe(query: "42", rewriteToken: UUID(), resultShown: true, at: at(3))
        expect(session.origin == .rewritten, "a new token with other text is an action's rewrite")

        var compact = LauncherHistorySession()
        expect(compact.upArrow(query: "", history: ["7 * 6"]) == .write("7 * 6"), "↑ in the compact bar")
        let recorded = compact.observe(query: "7 * 6", rewriteToken: UUID(), resultShown: true, at: at(0))
        expect(compact.origin == .recalled, "the list mounting after the recall still knows it")
        let left = compact.left(at: at(9), paletteHidden: true)
        expect(recorded.isEmpty && left.isEmpty, "and records nothing")
        var typed = LauncherHistorySession()
        _ = typed.observe(query: "7 * 6", rewriteToken: UUID(), resultShown: true, at: at(0))
        expect(typed.origin == .typed, "typing that expands the compact bar is typing")
    }

    // MARK: - Undo

    static func undoesARefusedConfirmation() {
        var undo = LauncherHistoryUndo()
        let before = LauncherHistory()
        var after = before
        after.record("empty trash", at: at(0))
        undo.recorded(before: before, after: after, at: at(0))
        undo.confirmationBegan(at: at(0.3))
        expect(undo.confirmationEnded(accepted: false, current: after) == before, "Cancel undoes it")
        undo.recorded(before: before, after: after, at: at(1))
        undo.confirmationBegan(at: at(1.2))
        expect(undo.confirmationEnded(accepted: true, current: after) == nil, "Confirm keeps it")
        undo.recorded(before: before, after: after, at: at(2))
        undo.confirmationBegan(at: at(30))
        expect(undo.confirmationEnded(accepted: false, current: after) == nil, "a later dialog is unrelated")
        var later = after
        later.record("other", at: at(41))
        undo.recorded(before: before, after: after, at: at(40))
        undo.confirmationBegan(at: at(40.5))
        expect(undo.confirmationEnded(accepted: false, current: later) == nil, "a newer write is kept")
        var menuThenLaunch = after
        menuThenLaunch.record("empty trash", at: at(50.1))
        undo.recorded(before: before, after: after, at: at(50))
        undo.recorded(before: after, after: menuThenLaunch, at: at(50.1))
        undo.confirmationBegan(at: at(50.2))
        expect(
            undo.confirmationEnded(accepted: false, current: menuThenLaunch) == before,
            "a menu row and the launch it runs undo together")
    }

    static func undoesALaunchThatAskedForArguments() {
        var undo = LauncherHistoryUndo()
        let before = LauncherHistory()
        var after = before
        after.record("deploy", at: at(0))
        undo.recorded(before: before, after: after, at: at(0))
        expect(undo.withdraw(current: after, at: at(0)) == before, "a missing argument undoes it")
        undo.recorded(before: before, after: after, at: at(1))
        expect(undo.withdraw(current: after, at: at(9)) == nil, "but only for its own launch")
    }

    static func forgetsEverythingOnLock() {
        var session = LauncherHistorySession()
        _ = session.upArrow(query: "", history: ["A"])
        _ = session.observe(query: "A", rewritten: true, resultShown: true, at: at(0))
        session.reset()
        expect(session == LauncherHistorySession(), "locking drops the walk and pending results")
    }
}
