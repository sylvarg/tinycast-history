# Patches no longer apply to upstream e139ed4

Nothing was published: `main` and the releases stay as they were. [Run log](https://github.com/sylvarg/tinycast-history/actions/runs/45034193445).

**`0001-sealed-storage`** no longer applies to upstream [`e139ed4`](https://github.com/abue-ammar/tinycast/commit/e139ed4ff9961eec8919671d2850c3d2a65f7bee): `Tinycast/Features/Calculator/Service/CalculatorHistoryStore.swift`, `Tinycast/Features/Launcher/Model/LauncherRankingStore.swift`.

Upstream commits since the last built upstream [`6fa8ba1`](https://github.com/abue-ammar/tinycast/commit/6fa8ba1225be0777ef769f1816bffc7da213f91d) that touch it:

- [`876b61dc`](https://github.com/abue-ammar/tinycast/commit/876b61dc64397444a8f1c45629530e5657552d3e) Run Settings in its own process (#1966)

If one of them ships what the patch does, drop the patch and its README row; otherwise redo the hunk on top of it (see `.personal/README.md`, *Updating a patch*).

<details><summary>Where it stops</summary>

```diff
diff --cc Tinycast/Features/Calculator/Service/CalculatorHistoryStore.swift
index 61495faf,f14140a3..00000000
--- a/Tinycast/Features/Calculator/Service/CalculatorHistoryStore.swift
+++ b/Tinycast/Features/Calculator/Service/CalculatorHistoryStore.swift
@@@ -30,22 -30,16 +30,35 @@@ final class CalculatorHistoryStore 
      /// Bumped on every persisted mutation, so the key above names the entries it filtered.
      private var revision = 0
  
++<<<<<<< ours
 +    init() {
 +        fileURL = AppPaths.applicationSupport().appendingPathComponent("calculator-history.json")
 +        entries = Self.stored(at: fileURL)
 +    }
 +
 +    /// Adopts a history another process wrote.
 +    func reload() {
 +        let stored = Self.stored(at: fileURL)
 +        guard stored != entries else { return }
 +        entries = stored
 +        revision &+= 1
 +    }
 +
 +    private static func stored(at fileURL: URL) -> [CalcHistoryEntry] {
 +        (try? Data(contentsOf: fileURL))
 +            .flatMap { try? JSONDecoder().decode([CalcHistoryEntry].self, from: $0) } ?? []
++=======
+     init(file: SealedFile = .calculatorHistory) {
+         self.file = file
+ 
+         if let data = try? file.read(),
+             let decoded = try? JSONDecoder().decode([CalcHistoryEntry].self, from: data)
+         {
+             entries = decoded
+         } else {
+             entries = []
+         }
++>>>>>>> theirs
      }
  
      func record(expression: String, result: String) {
diff --cc Tinycast/Features/Launcher/Model/LauncherRankingStore.swift
index 5441e988,9b5258b8..00000000
--- a/Tinycast/Features/Launcher/Model/LauncherRankingStore.swift
+++ b/Tinycast/Features/Launcher/Model/LauncherRankingStore.swift
@@@ -43,23 -47,21 +47,38 @@@ final class LauncherRankingStore 
      /// The in-flight persist, awaited by the next one so a burst can't land out of order.
      @ObservationIgnored private var writeTask: Task<Void, Never>?
  
-     init(fileURL: URL? = nil, now: @escaping () -> Date = Date.init) {
+     init(
+         fileURL: URL? = nil, now: @escaping () -> Date = Date.init, persistence: Persistence? = nil
+     ) {
          self.fileURL = fileURL ?? Self.defaultFileURL()
          self.now = now
++<<<<<<< ours
 +        visits = Self.live(Self.stored(at: self.fileURL), at: now())
 +    }
 +
 +    /// Adopts a table another process wrote.
 +    func reload() {
 +        let stored = Self.live(Self.stored(at: fileURL), at: now())
 +        guard stored != visits else { return }
 +        visits = stored
 +        revision &+= 1
 +    }
 +
 +    private static func stored(at fileURL: URL) -> [String: LauncherVisit] {
 +        (try? Data(contentsOf: fileURL))
 +            .flatMap { try? JSONDecoder().decode([String: LauncherVisit].self, from: $0) } ?? [:]
++=======
+         self.persistence = persistence
+         let stored: Data?
+         if let persistence {
+             stored = persistence.load()
+         } else {
+             stored = try? Data(contentsOf: self.fileURL)
+         }
+         let decoded =
+             stored.flatMap { try? JSONDecoder().decode([String: LauncherVisit].self, from: $0) } ?? [:]
+         visits = Self.live(decoded, at: now())
++>>>>>>> theirs
      }
  
      var isEmpty: Bool { visits.isEmpty }
```

</details>

<!-- cause: 0001-sealed-storage: Tinycast/Features/Calculator/Service/CalculatorHistoryStore.swift Tinycast/Features/Launcher/Model/LauncherRankingStore.swift -->
