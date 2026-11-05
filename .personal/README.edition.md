# Tinycast — personal edition with history

*English · [Français](README.fr.md)*

A **personal, public and unofficial edition** of [Tinycast](https://github.com/abue-ammar/tinycast),
the macOS launcher by Abue Ammar. It is still the **Tinycast** app (`Tinycast.app`,
`com.tinycast.app`), replaces the official install and keeps its settings and data, and adds a single
feature: **recall the launcher's validated inputs with ↑**.

> This repository is not the official project and is not endorsed by its author. The original
> request, [abue-ammar/tinycast#1570](https://github.com/abue-ammar/tinycast/issues/1570) "Calculator
> HIstory (or Launcher history in general)", was **closed as `not_planned`** on 14 October 2026: the
> maintainer [declined](https://github.com/abue-ammar/tinycast/issues/1570#issuecomment-6163760400) to
> maintain such a history, in line with the [position on customisations](https://github.com/abue-ammar/tinycast/issues/1554).
> The feature therefore belongs to this edition alone; please do not report it to the original
> project.
>
> This edition is published **as is, for personal use, without support**: issues are disabled on this
> repository and no report is followed up here.

## The feature

- In the launcher, with the field **empty**, **↑** puts the latest validated input back in the field,
  caret at the end: results, the calculator card, the primary action and the ⌘K menu update exactly
  as if you had typed it. Each further ↑ goes one entry older, down to the oldest (no wrap-around).
- **↓** always moves through the recalled input's results (then ↵, ⌘K…). There is no way back to more
  recent inputs.
- As soon as you edit the text, ↑ is row navigation again; empty the field to start over from the
  most recent input.
- An input is recorded when an action is actually run from the bar (opening an app, a command, a
  quicklink, an extension command, a ⌘K row, a copy…) **or** when a calculation result (conversions,
  time zones and dates included) or a colour card is actually shown — even if you then close with
  Escape. Recalling an entry does not record it; validating it again moves it to the top, without a
  duplicate. At most 100 entries.
- **Clear Launcher History** (a launcher command) erases this history and its key after a
  confirmation, leaving the clipboard and calculator histories untouched.

Details and limits: [docs/features/launcher-history.md](docs/features/launcher-history.md).

## Data protection

The history (`command-input-history.enc`), **and also** the calculator history and the search terms
the launcher learns — which hold the same inputs — are encrypted on disk (AES-256-GCM, CryptoKit),
each with its own random key kept only in **your macOS keychain** and readable by this signed app.
The former plain files (`calculator-history.json`, `launcher-ranking.json`) are migrated, then
deleted. Backup exports no longer include calculations or search terms. This protection is **at
rest**: a copied or restored file is unreadable without the key, but a compromised Mac or an unlocked
session is not protected. Copies made earlier (backups, Time Machine, exports) cannot be erased
retroactively. Going back to the official version starts these histories empty (it cannot read the
encrypted files).

## Installation (Apple silicon, macOS 26 or later)

1. Download `Tinycast-<version>.dmg` from the [releases](https://github.com/sylvarg/tinycast-history/releases)
   and, if you wish, check its fingerprint (`.sha256`).
2. Quit Tinycast if it is running, then drag **Tinycast** to **Applications**, replacing the official
   copy. Settings, shortcuts, clipboard, notes and snippets are kept.
3. The app is self-signed (not notarised by Apple). Once, in Terminal:
   `xattr -dr com.apple.quarantine /Applications/Tinycast.app` — or, at first launch, *System Settings
   › Privacy & Security › Open Anyway*.
4. Its certificate differs from the official version's, so macOS asks for **Accessibility** again
   (System Settings › Privacy & Security › Accessibility: remove the old Tinycast entry, add the new
   one) and, if you use AI or MCP providers, for access to the keys the previous version saved
   ("Always Allow").
5. About Tinycast shows **"Personal edition with history"**, the official base version and the
   personal revision.

**Updates**: once a day (*Automatically check for updates*, on by default) or through *Check for
Updates*, the app reads **this repository's** releases and offers the new version in a window; once
you accept, it downloads it, verifies the identifier, the version and the signature (the same
certificate as the installed app), installs it and relaunches. `0.12.1-h.2` corrects `0.12.1-h.1`;
the next official release arrives as `0.12.2-h.1`. Homebrew is not involved.

**Going back**: quit Tinycast and install the DMG of an earlier release from this repository (or the
official version) into Applications. An older version of this edition reads the same encrypted
files; the official version cannot (empty histories) and recreates its plain files.

## Build and maintenance

Everything is built and tested by GitHub Actions on macOS; no local Xcode is needed. The app is
compiled only when it is released: each official stable release is rebuilt from its exact tag with
the patches from [`.personal/`](.personal/README.md), tested, signed and published here, and `main`
then points at that source. A daily check, without compiling, warns early if the patches stop
applying to the official development branch. Maintenance, the inventory of changes
to the original code and diagnostics: [`.personal/README.md`](.personal/README.md). Signing:
[`.personal/SIGNING.md`](.personal/SIGNING.md). Original README: [README.upstream.md](README.upstream.md).

## Credits and licence

Tinycast is © Abue Ammar and its contributors, under the **AGPL-3.0** licence ([LICENSE](LICENSE),
[NOTICE.md](NOTICE.md)); this edition and its changes are published under the same licence, with the
complete source of every version (tag `v<version>` and the `.personal/patches` folder). The patch and
release mechanics are inspired by [Tinycast Space](https://github.com/sermelipharo/tinycast-space) by
sermelipharo; none of its features are included.
