# Patches no longer apply to upstream ed7c291

Nothing was published: `main` and the releases stay as they were. [Run log](https://github.com/sylvarg/tinycast-history/actions/runs/45664027822).

**`0002-launcher-history`** no longer applies to upstream [`ed7c291`](https://github.com/abue-ammar/tinycast/commit/ed7c29170eec79444ef6639a449f421bf78e18c3): `Tinycast/Features/DeepLinks/Model/DeepLinkConsentPolicy.swift`.

Upstream commits since the last built upstream [`6fa8ba1`](https://github.com/abue-ammar/tinycast/commit/6fa8ba1225be0777ef769f1816bffc7da213f91d) that touch it:

- [`ce14fd3d`](https://github.com/abue-ammar/tinycast/commit/ce14fd3d961e347717bb54abeda72d4841872601) Share the pill HUD and drop Add Window to Current Room (#1987)
- [`90a35d39`](https://github.com/abue-ammar/tinycast/commit/90a35d39b8bbd38d7c3c3b043a73c366c1b92896) Add room shortcuts and a room HUD (#1985)

If one of them ships what the patch does, drop the patch and its README row; otherwise redo the hunk on top of it (see `.personal/README.md`, *Updating a patch*).

<details><summary>Where it stops</summary>

```diff
diff --cc Tinycast/Features/DeepLinks/Model/DeepLinkConsentPolicy.swift
index ba072c23,7651fc38..00000000
--- a/Tinycast/Features/DeepLinks/Model/DeepLinkConsentPolicy.swift
+++ b/Tinycast/Features/DeepLinks/Model/DeepLinkConsentPolicy.swift
@@@ -46,7 -46,7 +46,11 @@@ enum DeepLinkConsentPolicy 
          switch id {
          case .fixGrammar, .rewrite, .translate, .summarize, .pasteSequentially, .openCamera,
              .joinNextMeeting, .copyMeetingLink, .openInCalendar, .captureWindowLayout, .openInBrowser,
++<<<<<<< ours
 +            .runShellCommand, .switchToPreviousRoom, .tidyCurrentRoom, .quit:
++=======
+             .runShellCommand, .quit, .clearLauncherHistory:
++>>>>>>> theirs
              true
          case .quickAI, .aiChat, .calculatorHistory, .clipboardHistory, .searchEmoji, .searchFiles,
              .searchMenuItems, .switchWindows, .switchWindowsBackwards, .createCustomCommand,
```

</details>

<!-- cause: 0002-launcher-history: Tinycast/Features/DeepLinks/Model/DeepLinkConsentPolicy.swift -->
