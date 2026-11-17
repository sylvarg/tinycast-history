# Patches no longer apply to upstream af5e7c2

Nothing was published: `main` and the releases stay as they were. [Run log](https://github.com/sylvarg/tinycast-history/actions/runs/44122873311).

**`0001-sealed-storage`** no longer applies to upstream [`af5e7c2`](https://github.com/abue-ammar/tinycast/commit/af5e7c2e95709114047476de65c37770c08fcdf7): `docs/migrations.md`.

Upstream commits since the last built upstream [`6fa8ba1`](https://github.com/abue-ammar/tinycast/commit/6fa8ba1225be0777ef769f1816bffc7da213f91d) that touch it:

- [`4a3d4440`](https://github.com/abue-ammar/tinycast/commit/4a3d4440d6bbe463338391a4b060d0d3824f7db3) Remove the bundle id migration and the old pasteboard fallback (#1931)

If one of them ships what the patch does, drop the patch and its README row; otherwise redo the hunk on top of it (see `.personal/README.md`, *Updating a patch*).

<details><summary>Where it stops</summary>

```diff
diff --cc docs/migrations.md
index 54846d81,d3a902e2..00000000
--- a/docs/migrations.md
+++ b/docs/migrations.md
@@@ -31,3 -36,55 +31,58 @@@ When the check fails, delete everythin
  
  | Migration | Repairs | Delete with it |
  | --- | --- | --- |
++<<<<<<< ours
++=======
+ | `BundleIdentifierMigration` | Moves `com.tinycast.app[.beta\|.dev]`'s preferences, Application Support and Caches folders and login item to `com.abueammar.tinycast[.beta\|.dev]`, and repoints every saved path into the old folders: in preferences (JSON-encoded ones too), JSON files, clipboard and quicklink rows, and `settings.json`. A `paths-repointed` marker in its backup makes it repair, once, a copy 0.12.14-beta.141 moved without repointing. Keychain secrets stay behind: moving them asks once per item, so users enter them again. Kept until **2027-05-13** | Everything in [Removing the bundle id move](#removing-the-bundle-id-move) |
+ | `SealedKeyringMigration` | Personal edition: moves the sealed files' keyring item from `com.tinycast.app[.dev].sealed-storage-keys` to the new id's on first use, since without it the encrypted histories cannot be opened. Asks once, like any new build of this self-signed edition. Kept until **2027-05-13**, with the bundle id move | `Tinycast/Migrations/SealedKeyringMigration.swift`; `SealedFile`'s `legacyKeychain` and its use in `keyring()`; `movesTheKeyringFromTheOldBundleID` in `Tests/sealed-storage-test.swift` |
+ 
+ ### Removing the bundle id move
+ 
+ The migration and the handoff release are one piece, and go together. Afterwards, searching the repo
+ for `Handoff`, `LEGACY`, `BundleIdentifierMigration` and `com.tinycast.app` finds nothing.
+ 
+ **Delete these files**
+ 
+ - `Tinycast/Migrations/BundleIdentifierMigration.swift`
+ - `Tinycast/Migrations/Handoff/`, the whole folder: `BundleIdentifierHandoff.swift` and `Info.plist`
+ - `Tests/BundleIdentifierMigrationTests.swift`
+ - `Scripts/wrap-handoff.sh`
+ - `Scripts/package-handoff.sh`
+ 
+ **Remove these lines**
+ 
+ - `Tinycast/App/TinycastApp.swift`: the `BundleIdentifierMigration.run()` call in
+   `TinycastLaunch.main`.
+ - `Tinycast/Features/Updates/Model/ReleaseFeed.swift`: `handoffMarker` and its doc comment, and its
+   check in `asset(from:for:)`, so the filter is `$0.name.hasSuffix(".zip")` again.
+ - `Tests/UpdatesTests.swift`: the `com.tinycast.app` expectation in `derivesChannels`, and the
+   `handoff` and `handoffOnly` cases at the end of `picksTheZipThisMacCanRun`.
+ - `Scripts/run-tests.sh`: the `run BundleIdentifierMigrationTests` entry.
+ - `Scripts/check-migrations.sh`: the dated-row block: its comment, the `until=` line and the
+   `if [ -n "$until" ]` block around `continue`.
+ - `project.yml`: both `TINYCAST_LEGACY_BUNDLE_IDENTIFIER` settings, the `Migrations/Handoff` exclude
+   in the `Tinycast` target, and the whole `TinycastHandoff` target with its comment. Then run
+   `xcodegen generate`, so `Tinycast.xcodeproj` loses them too.
+ - `.github/workflows/release.yml`:
+   - the `legacy_bundle_id` job output;
+   - in "Compute release metadata", the `LEGACY=` line with its comment, and the `legacy_bundle_id`
+     and `handoff_file` echoes;
+   - both "Build and notarize the handoff" steps, and the comment above the build job's one;
+   - in "Publish GitHub Release", the handoff files in `gh release create`: give it the DMG, the zip
+     and the `.sig` again, and delete the second `gh release upload` call with its comment;
+   - in the `universal` job, the `LEGACY_BUNDLE_ID` env, and the first `gh release upload` call (the
+     handoff) with the comment after it.
+ 
+ **Edit these docs**
+ 
+ - [testing.md](testing.md): the `BundleIdentifierMigrationTests` row.
+ - [release.md](release.md): the whole "The bundle id handoff" section.
+ - [features/updates.md](features/updates.md): the paragraph under the channel table that starts
+   "Until 2027-05-13".
+ - This file: the "Except a dated row" invariant, the "or from `TinycastLaunch.main`" clause in
+   [Adding one](#adding-one), the `BundleIdentifierMigration` row and this section.
+ 
+ **Left on users' Macs, with no code to remove it:** an empty `com.tinycast.app*.plist`, Keychain
+ secrets under the old names, stale permission entries in System Settings, and a `Migration Backup`
+ folder for anyone migrated in the last 30 days.
++>>>>>>> theirs
```

</details>

<!-- cause: 0001-sealed-storage: docs/migrations.md -->
