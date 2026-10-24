import SwiftUI

/// Owns the launcher's input history: ↑ recall, what counts as validated, and its sealed file.
@MainActor
final class LauncherHistoryCoordinator {
    private let palette: PaletteState
    private let store: LauncherHistoryStore
    private let now: () -> Date
    /// Dialogs and HUDs only, through the forwarders every feature uses.
    private unowned let core: AppCore
    private var session = LauncherHistorySession()
    private var undo = LauncherHistoryUndo()
    private var isLocked = false
    /// Set between a palette launch and its return, the span its own argument request lands in.
    private var isLaunchingFromPalette = false
    private var observers: [NotificationToken] = []
    /// One HUD per file and session, so a broken key does not report on every keystroke.
    private var reportedFiles: Set<String> = []

    init(
        palette: PaletteState, core: AppCore, store: LauncherHistoryStore = LauncherHistoryStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.palette = palette
        self.core = core
        self.store = store
        self.now = now
    }

    func start() {
        let distributed = DistributedNotificationCenter.default()
        observers = [
            observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.lock() },
            observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.unlock() },
            observe(NotificationCenter.default, SealedFile.didFailNotification) { coordinator in
                coordinator.reportUnavailable()
            }
        ]
        // The calculator and ranking stores read their files before anything could listen.
        reportUnavailable()
    }

    // MARK: - Recall

    /// ↑ in the launcher's own field; true when the key recalled, or sat at the oldest entry.
    func recall(modifiers: EventModifiers, menuOpen: Bool, fieldFocused: Bool) -> Bool {
        guard palette.mode == .launcher, fieldFocused, !menuOpen, !isLocked,
            modifiers.isDisjoint(with: [.command, .option, .control, .shift]),
            !palette.isComposing, !palette.isControlListOpen
        else { return false }
        let query = palette.query
        guard query.isEmpty || session.recall != nil else { return false }
        guard let history = store.history() else {
            if query.isEmpty { reportUnavailable() }
            return false
        }
        switch session.upArrow(query: query, history: history.texts) {
        case .ignore: return false
        case .stay: return true
        case .write(let text):
            palette.rewriteQuery(text)
            return true
        }
    }

    // MARK: - What the launcher shows

    /// The field and its lead card as last drawn, from `LauncherHistoryObserver`.
    func observe(query: String, rewriteToken: UUID, resultShown: Bool) {
        record(
            session.observe(query: query, rewriteToken: rewriteToken, resultShown: resultShown, at: now()))
    }

    /// A hidden palette also drops the decrypted entries; the next ↑ or record reads them again.
    func launcherLeft(paletteHidden: Bool) {
        record(session.left(at: now(), paletteHidden: paletteHidden))
        if paletteHidden { store.release() }
    }

    // MARK: - Validation

    /// An action ran on the launcher's query: a row, a menu item, a copy, an answer chained on.
    func noteAction() {
        guard palette.mode == .launcher, palette.isVisible, !isLocked,
            let text = session.validate()
        else { return }
        record([text], undoable: true)
    }

    /// The launch funnel: only the palette passes a query, so a hotkey's launch records nothing.
    func noteLaunch(searchQuery: String?) {
        isLaunchingFromPalette = searchQuery != nil
        if isLaunchingFromPalette { noteAction() }
    }

    /// After a launch dispatched: one that asked for its arguments instead did not run.
    func launchDispatched() {
        defer { isLaunchingFromPalette = false }
        guard isLaunchingFromPalette, !isLocked, palette.pendingArgumentEntryID != nil,
            let history = store.history(),
            let restored = undo.withdraw(current: history, at: now())
        else { return }
        store.save(restored)
    }

    func confirmationWillBegin() {
        undo.confirmationBegan(at: now())
    }

    func confirmationDidEnd(confirmed: Bool) {
        guard !isLocked, let history = store.history(),
            let restored = undo.confirmationEnded(accepted: confirmed, current: history)
        else { return }
        store.save(restored)
    }

    /// A result still on screen at quit was read; it is recorded as a hide would record it.
    func prepareForTermination() {
        if palette.isVisible, palette.mode == .launcher { launcherLeft(paletteHidden: true) }
    }

    // MARK: - Clear Launcher History

    func clearHistory() async {
        guard
            await core.confirm(
                title: String(localized: "Clear launcher history?", table: "PersonalEdition"),
                message: String(
                    localized: "Every recalled search goes, and its key with it. This can't be undone.",
                    table: "PersonalEdition"),
                symbol: CommandID.clearLauncherHistory.sfSymbol,
                confirmTitle: String(localized: "Clear History", table: "PersonalEdition"))
        else { return }
        do {
            try store.erase()
        } catch {
            await core.showNotice(
                title: String(localized: "Couldn’t clear launcher history", table: "PersonalEdition"),
                message: error.localizedDescription, symbol: "exclamationmark.triangle",
                tone: .danger)
            return
        }
        session.reset()
        undo.clear()
        reportedFiles.remove(SealedFile.launcherHistory.url.lastPathComponent)
        core.showMessage(String(localized: "Launcher history cleared", table: "PersonalEdition"))
    }

    // MARK: - Private

    private func record(_ texts: [String], undoable: Bool = false) {
        guard !isLocked else { return }
        guard !texts.isEmpty, let before = store.history() else {
            if !texts.isEmpty { reportUnavailable() }
            return
        }
        var after = before
        let timestamp = now()
        for text in texts { after.record(text, at: timestamp) }
        guard after != before, store.save(after) else { return }
        if undoable { undo.recorded(before: before, after: after, at: timestamp) }
    }

    /// Locking forgets the walk, the decrypted entries and any undo; unlocking reads them anew.
    private func lock() {
        isLocked = true
        session.reset()
        undo.clear()
        store.release()
    }

    private func unlock() {
        isLocked = false
    }

    private func reportUnavailable() {
        let files: [SealedFile] = [.launcherHistory, .calculatorHistory, .launcherRanking]
        let failed = files
            .filter { $0.blocked || $0 === SealedFile.launcherHistory && store.isUnavailable }
            .map(\.url.lastPathComponent)
            .filter { !reportedFiles.contains($0) }
        guard !failed.isEmpty else { return }
        reportedFiles.formUnion(failed)
        let names = failed.joined(separator: ", ")
        core.showMessage(
            String(localized: "Encrypted history unavailable: \(names)", table: "PersonalEdition"),
            tone: .danger)
    }

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name,
        _ handler: @escaping @Sendable @MainActor (LauncherHistoryCoordinator) -> Void
    ) -> NotificationToken {
        NotificationToken(
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handler(self)
                }
            }, center: center)
    }
}
