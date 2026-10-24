#!/bin/bash
# The one-line hooks the history needs in upstream files: losing one in a merge fails loudly here.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
status=0
need() { grep -qF -- "$2" "$1" || { echo "missing in $1: $2"; status=1; }; }
need Tinycast/Palette/RootPaletteView.swift "core.launcherHistoryCoordinator.recall("
need Tinycast/Palette/RootPaletteView.swift "if openMenu == .actions { core.launcherHistoryCoordinator.noteAction() }"
need Tinycast/Features/Launcher/UI/LauncherScreen.swift "core.launcherHistoryCoordinator.noteAction()"
need Tinycast/Features/Launcher/UI/LauncherScreen.swift ".launcherHistory("
need Tinycast/Features/Launcher/UI/LauncherCoordinator.swift "core.launcherHistoryCoordinator.noteLaunch(searchQuery: searchQuery)"
need Tinycast/Features/Launcher/UI/LauncherCoordinator.swift "defer { core.launcherHistoryCoordinator.launchDispatched() }"
need Tinycast/Features/Launcher/UI/LauncherCoordinator.swift "case .clearLauncherHistory:"
need Tinycast/Features/Calculator/UI/CalculatorCoordinator.swift "core.launcherHistoryCoordinator.noteAction()"
need Tinycast/Features/AI/UI/QuickAICoordinator.swift "core.launcherHistoryCoordinator.noteAction()"
need Tinycast/App/AppCore.swift "launcherHistoryCoordinator.confirmationWillBegin()"
need Tinycast/App/AppCore.swift "launcherHistoryCoordinator.prepareForTermination()"
need Tinycast/App/AppCore.swift "LauncherRankingStore(persistence: SealedFile.launcherRanking.loadAndSave)"
need Tinycast/Features/Calculator/Service/CalculatorHistoryStore.swift "init(file: SealedFile = .calculatorHistory)"
need Tinycast/Features/Updates/Model/ReleaseFeed.swift 'static let repository = "sylvarg/tinycast-history"'
need Tinycast/Windows/About/AboutView.swift "PersonalEditionSection()"
# No plaintext path may survive for the sealed stores.
# LauncherRankingStore keeps upstream's default URL for its harnesses; AppCore always passes the seal.
if grep -rn '"calculator-history.json"\|"launcher-ranking.json"' Tinycast --include=*.swift \
  | grep -v 'legacyName:\|LauncherRankingStore.swift:.*appendingPathComponent'; then
  echo "a sealed store's legacy file name is used outside its migration"; status=1
fi
grep -q 'satisfiesDeveloperID(staticCode' Tinycast/Features/Updates/Service/BundleSignature.swift \
  && { echo "upstream's Developer ID team is still trusted by the updater"; status=1; }
exit $status
