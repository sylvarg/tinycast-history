import SwiftUI

extension View {
    /// Reports the launcher's field and lead card as drawn, which is what "shown" means here.
    func launcherHistory(
        _ coordinator: LauncherHistoryCoordinator, palette: PaletteState, resultShown: Bool
    ) -> some View {
        modifier(
            LauncherHistoryObserver(coordinator: coordinator, palette: palette, resultShown: resultShown))
    }
}

/// One change handler for the field, its rewrite token and the card, so they arrive in one event.
private struct LauncherHistoryObserver: ViewModifier {
    let coordinator: LauncherHistoryCoordinator
    let palette: PaletteState
    let resultShown: Bool

    private struct Drawn: Equatable {
        let query: String
        let rewriteToken: UUID
        let resultShown: Bool
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: drawn, initial: true) { _, drawn in
                coordinator.observe(
                    query: drawn.query, rewriteToken: drawn.rewriteToken, resultShown: drawn.resultShown)
            }
            .onChange(of: palette.isVisible) { _, visible in
                if !visible { coordinator.launcherLeft(paletteHidden: true) }
            }
            .onDisappear { coordinator.launcherLeft(paletteHidden: !palette.isVisible) }
    }

    private var drawn: Drawn {
        Drawn(query: palette.query, rewriteToken: palette.queryRewriteToken, resultShown: resultShown)
    }
}
