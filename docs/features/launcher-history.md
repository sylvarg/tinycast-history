# Launcher history (personal edition)

**This feature exists only in the personal edition [`sylvarg/tinycast-history`](https://github.com/sylvarg/tinycast-history).**
It was requested upstream in [abue-ammar/tinycast#1570](https://github.com/abue-ammar/tinycast/issues/1570)
("Calculator HIstory (or Launcher history in general)"), which the maintainer closed as `not_planned`
on 14 October 2026 and declined to maintain. Nothing here is part of, or proposed to, the original
project. The maintenance mechanics are in [`.personal/README.md`](../../.personal/README.md).

↑ in an empty launcher field puts the most recent validated input back in the field, as if typed:
results, the calculator card, the primary action and ⌘K all follow. Each further ↑ goes one entry
older. ↓ always moves through the results; there is no walk back towards newer entries.

## Invariants

- **Recall starts only from a strictly empty field.** `↑` with no ⌘ ⌥ ⌃ ⇧, in `.launcher`, with the
  search field focused, no argument field focused, no menu or control list open and no IME
  composition. With any typed text, even a space, `↑` keeps its row navigation.
- **The recalled text is a real query.** It is written through `PaletteState.rewriteQuery`, the same
  path ⌘↵ uses to chain an answer, so the field, the caret, the results and the actions are exactly
  those of a typed query. Recall itself never runs anything.
- **A walk continues only while the field still holds what `↑` wrote.** Any edit, paste or deletion,
  another rewrite, a screen change, hiding the palette or locking the session ends it; the next walk
  starts again from the newest entry once the field is empty. It stops at the oldest entry and never
  loops. The walk uses a snapshot taken on the first `↑`.
- **Recalling records nothing; validating a recalled entry promotes it.** The same entry (same id)
  moves to the front with a new `lastValidatedAt`, persisted; the count never grows.
- **Only the launcher's own field is recorded.** Argument fields, chats, notes, extension searches and
  every other screen are never read.
- **Nothing is written in the clear.** The history lives only in `command-input-history.enc`, sealed
  with its own Keychain key; see [Storage](#storage).

## What counts as validated

A text is recorded when one of these happens to the launcher's query (empty or whitespace-only text
is never recorded, and text an action wrote — the answer ⌘↵ puts in the field — is never an input):

| Event | Where it is noticed |
| --- | --- |
| ↵ or a click on a card, a file or a fallback row | `LauncherScreen.activate` |
| A click on an entry row, or a ⌘K row that launches it | `LauncherCoordinator.launch` (only when it carries the palette's `searchQuery`) |
| Any row of the launcher's ⌘K Actions menu | `RootPaletteView.activateMenuItem` |
| ⌘↵ / ⇧⌘↵ on the calculator card | `CalculatorCoordinator.putAnswerInSearchBar` / `copyCalculationWithExpression` |
| ⌘↵ (Show in Finder), ⌘R (Restart), ⌃⇧Q (Quit) on an app | `LauncherCoordinator.showInFinder` / `restart` / `quit` |
| ⇥ or the fallback row asking Quick AI | `QuickAICoordinator.ask` |
| **A result shown**: the calculator card with a value, or the color card | `LauncherHistoryObserver` on `LauncherList` |

Opening ⌘K is not a validation; only running one of its rows is. A ↵ blocked by an empty required
argument never reaches `activate`, so it records nothing.

**Undo.** A validation is held for two seconds as `LauncherHistoryUndo`. If the action then asks a
confirmation (`AppCore.confirm`) or a volume (`AppCore.pickVolume`) and the answer is Cancel, or a
launch from the palette asks for its arguments instead of running (`pendingArgumentEntryID` set), the
history is restored to what it was — provided nothing else changed it meanwhile. A menu row and the
launch it runs undo together.

**Shown results.** A result counts as shown when the launcher drew it for typed text and it stayed
on screen for 0.7 s, or the palette was hidden (Escape, a click away, quitting) while it was there.
A result typed straight past, a loading or error card, a plain list of matches and a recalled
entry's own result are not recorded. Showing the same result again (re-opening a preserved screen)
is not a second event, and copying a shown answer records it once.

Validation records the field's text at the moment of the action, before the action closes or resets
the palette; nothing waits for a process, a network request or the app to finish opening.

## Architecture

| File | Layer | Role |
| --- | --- | --- |
| `Features/LauncherHistory/Model/LauncherHistory.swift` | pure | Entries (id, text, lastValidatedAt), newest first, unique text, capacity 100 |
| `Features/LauncherHistory/Model/LauncherHistorySession.swift` | pure | `LauncherHistorySession` (recall walk, origins, shown results) and `LauncherHistoryUndo` |
| `Features/LauncherHistory/Service/LauncherHistoryStore.swift` | effect | Loads the sealed file on first use, saves, releases on lock, erases |
| `Features/LauncherHistory/UI/LauncherHistoryCoordinator.swift` | coordinator | Owned by `AppCore`; applies the session to the palette and the store; lock; Clear |
| `Features/LauncherHistory/UI/LauncherHistoryObserver.swift` | view | One `onChange` for query, rewrite token and card, so they arrive as one event |
| `Platform/SealedEnvelope.swift` | pure crypto | AES-256-GCM envelope |
| `Platform/SealedFile.swift` | effect | Sealed file + Keychain key + migration + atomic private writes |
| `Windows/About/PersonalEditionSection.swift` | view | About › Personal edition with history |
| `Resources/PersonalEdition.xcstrings` | strings | The edition's own table, in all eight languages |

`AppCore.launcherHistoryCoordinator` is the only owner. The model files are Foundation-only and
compiled verbatim by `Tests/launcher-history-test.swift`. The coordinator is told about the
palette through short hooks in upstream files; [`.personal/README.md`](../../.personal/README.md)
lists each one and why it is needed.

**Clear Launcher History** is a launcher command (`CommandID.clearLauncherHistory`, listed in
Settings › Commands). It asks through `DialogController`, then deletes the file and its key and
reports with a HUD; the clipboard history and the calculator history are untouched.

## Storage

| Data | File (Application Support/`<bundle id>`) | Keychain account | Notes |
| --- | --- | --- | --- |
| Launcher history | `command-input-history.enc` | `SealedFile.Account.launcherHistory` | new in this edition |
| Calculator history | `calculator-history.enc` | `SealedFile.Account.calculatorHistory` | migrated from `calculator-history.json` |
| Learned search terms (ranking) | `launcher-ranking.enc` | `SealedFile.Account.launcherRanking` | migrated from `launcher-ranking.json` |

**Envelope.** `"TCSE"`, version byte `1`, then `AES.GCM.SealedBox.combined` (12-byte random nonce,
ciphertext, 16-byte tag). The associated data is the header plus `tinycast-sealed-file:<file name>`,
so a file copied over another store's, or with an edited header, fails authentication before
anything is decoded. Everything personal — texts, dates, ids, results — is inside the ciphertext.

**Keys.** One random 256-bit `SymmetricKey` per store, created on the user's Mac by CryptoKit the
first time that store writes, and kept only as a generic password in the user's login keychain
(service `<bundle id>.sealed-storage-keys`, one account per store), through upstream's
`KeychainSecretStore`. It is never in the code, the binary, preferences, a neighbouring file, the
environment, a backup or CI. Separate keys mean erasing the history's key leaves the others readable.

**Who can read a key.** `SecItemAdd` on the macOS file-based keychain gives the item an access
control list whose only trusted application is the creator, recorded by its *designated
requirement* — for this self-signed build, `identifier "com.tinycast.app" and certificate leaf =
H"…"`. A later build signed with the same `Tinycast Self-Signed` certificate satisfies it, so updates
keep access without a prompt; any other app, including the official Tinycast signed with a different
certificate, gets the system's keychain prompt and is refused unless the user explicitly allows it.
This edition deliberately uses the file-based keychain: the data-protection keychain and access
groups need a provisioning profile, which a self-signed app without a paid Apple Developer account
cannot have ([TN3137](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains)).
`.personal/tests/signing.sh` checks this on CI with two real throwaway identities.

**Writes.** Encrypt in memory, write the envelope to a `0600` temporary created with `O_EXCL` in the
same folder, `fsync`, `rename` over the file. Only sealed bytes ever reach a write call. Files over
16 MiB are refused unread.

**Failure.** A missing key with an existing file, a refused Keychain access, a failed
authentication or an oversized file make that store *unavailable*: its read fails, every later
write in the session is refused (`SealedFile.Failure.blocked`), and a HUD names the file once. The
launcher keeps working; ↑ simply does nothing. Nothing ever falls back to plain text, and a missing
key never silently gets replaced by a new one over an existing file.

**Lock.** On `com.apple.screenIsLocked` the coordinator ends any walk, forgets pending results and
the undo, and releases the decrypted history; ↑ is inert until `com.apple.screenIsUnlocked`, after
which the file is read again on first use. Swift strings cannot be reliably zeroed, so this limits
how long plaintext stays referenced; it does not promise that no copy remains in memory.

## Migration

`SealedFile.read()` with a `legacyName`:

1. Only the sealed file: open it.
2. Only the legacy plain file: read it in memory, seal it with the store's key (creating it if
   needed), read the sealed file back and compare, and only then delete the plain file.
3. Both (a crash between 2's write and delete, or the official build ran again in between): the
   newer by modification date wins. A valid sealed file is never overwritten by an older plain one;
   a plain file written since by the official build is sealed in. The plain file is removed either way.

Any failure leaves the plain file where it was, blocks writes for the session and reports; the next
launch retries. Running it again is a no-op.

## Backups and exports

`BackupComposer` (Settings › Backup, Export Backup) no longer writes the calculator history, and
writes the ranking table without its search terms, so neither reaches the plain `.tinycast` archive
or its staging folder. The launcher history and every key are never exported. Importing an older
backup still restores both into their sealed files.

## Limits

- Protection is **at rest**: a copied or restored `.enc` file is unreadable without the key in that
  user's login keychain. The app necessarily holds decrypted entries in memory while it shows and
  recalls them; a compromised Mac, a process able to read its memory, or an unlocked screen are
  outside this protection.
- **Losing a key loses that store.** If the Keychain item is deleted or the login keychain is reset,
  the matching `.enc` stays unreadable and writes are blocked. Clear Launcher History removes the
  history file and key and starts afresh. For the calculator history or ranking, quit Tinycast and
  delete `calculator-history.enc` or `launcher-ranking.enc`; a new key is created on the next write.
- **Earlier copies cannot be taken back.** Exports, Time Machine snapshots or backups made before this
  edition (or by the official build) may still contain `calculator-history.json`,
  `launcher-ranking.json` or a `.tinycast` archive. Deleting a file on an SSD/APFS volume does not
  guarantee its blocks are erased; only FileVault protects those at rest.
- **Going back to the official build** loses access: it cannot read the `.enc` files and starts these
  histories empty (and would recreate plain files). There is deliberately no automatic plain export.
- Text you explicitly copy goes to the clipboard and, through upstream's Clipboard History, to its
  database; Quick AI questions asked with ⇥ live in upstream's chat history. Both are those features'
  own data, unchanged by this edition.
