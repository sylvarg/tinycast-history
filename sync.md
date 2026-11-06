# Patches no longer apply to upstream 6bf543f

Nothing was published: `main` and the releases stay as they were. [Run log](https://github.com/sylvarg/tinycast-history/actions/runs/42233531202).

**`0003-edition-identity`** no longer applies to upstream [`6bf543f`](https://github.com/abue-ammar/tinycast/commit/6bf543fc6e2d7b4ef00726fcc4c492e471d116e6): `Tinycast/Features/Updates/Model/ReleaseFeed.swift`, `Tinycast/Features/Updates/Service/BundleSignature.swift`.

Upstream commits since the last built upstream [`dc265b2`](https://github.com/abue-ammar/tinycast/commit/dc265b263ad9afad1978f79d1d3533bb144bef0a) that touch it:

- [`57111cff`](https://github.com/abue-ammar/tinycast/commit/57111cff30a00e60d97ae9a6f13512d581a2687e) Replace the update window with a pill in the palette (#1817)
- [`d129c177`](https://github.com/abue-ammar/tinycast/commit/d129c177d3037b3d761e8928443a75a8f6d1b5ba) Trust updates through a release key or the running identity, and install them at quit (#1808)

If one of them ships what the patch does, drop the patch and its README row; otherwise redo the hunk on top of it (see `.personal/README.md`, *Updating a patch*).

<details><summary>Where it stops</summary>

```diff
diff --cc Tinycast/Features/Updates/Model/ReleaseFeed.swift
index d80800b9,f26e9207..00000000
--- a/Tinycast/Features/Updates/Model/ReleaseFeed.swift
+++ b/Tinycast/Features/Updates/Model/ReleaseFeed.swift
@@@ -11,7 -11,8 +11,12 @@@ struct AvailableRelease: Codable, Hasha
  
  /// Nothing throws: an unusable body means nothing to install, and the pump retries.
  enum ReleaseFeed {
++<<<<<<< ours
 +    static let repository = "abue-ammar/tinycast"
++=======
+     /// Where releases come from, and what every `@handle` and `#304` in their notes points at.
+     static let repository = "sylvarg/tinycast-history"
++>>>>>>> theirs
  
      /// The only artifact with an x86_64 slice, so the only one an Intel Mac can install.
      private static let universalMarker = "-Universal-"
diff --cc Tinycast/Features/Updates/Service/BundleSignature.swift
index a038f7bf,e8b5908a..00000000
--- a/Tinycast/Features/Updates/Service/BundleSignature.swift
+++ b/Tinycast/Features/Updates/Service/BundleSignature.swift
@@@ -1,53 -1,46 +1,91 @@@
  import Foundation
  import Security
  
++<<<<<<< ours
++=======
+ /// Proves a staged bundle is ours: the personal edition trusts its own leaf, never upstream's team.
++>>>>>>> theirs
  enum BundleSignature {
 -    /// The team, not the certificate — a leaf is reissued on renewal and on a rename.
 +    /// Any team, so a new one still updates through the release key, but never an ad-hoc build.
      static let developerID = """
          anchor apple generic \
 -        and certificate leaf[subject.OU] = "J656U8XZ93" \
          and certificate 1[field.1.2.840.113635.100.6.2.6] exists \
          and certificate leaf[field.1.2.840.113635.100.6.1.13] exists
          """
  
++<<<<<<< ours
 +    /// Returned so the swap at quit can pin the exact bytes that were verified.
 +    static func trustedHash(of bundleURL: URL, releaseSigned: Bool) -> Data? {
 +        var staticCode: SecStaticCode?
 +        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
 +            let staticCode,
 +            let requirement = releaseSigned ? compiled(developerID) : runningRequirement,
 +            SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
 +        else { return nil }
 +        return uniqueHash(of: staticCode)
 +    }
 +
 +    /// An unsealed bundle can claim any identity, and a nested helper is where one hides.
 +    private static let flags = SecCSFlags(
 +        rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
 +
 +    private static func compiled(_ text: String) -> SecRequirement? {
 +        var requirement: SecRequirement?
 +        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess
 +        else { return nil }
 +        return requirement
 +    }
 +
 +    /// The running copy's own requirement, never a pinned one, so a renewed certificate matches.
 +    private static var runningRequirement: SecRequirement? {
 +        var code: SecCode?
 +        var staticCode: SecStaticCode?
 +        var requirement: SecRequirement?
 +        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
 +            SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
 +            SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess
 +        else { return nil }
 +        return requirement
 +    }
 +
 +    private static func uniqueHash(of staticCode: SecStaticCode) -> Data? {
 +        var information: CFDictionary?
 +        let options = SecCSFlags(rawValue: kSecCSSigningInformation)
 +        guard SecCodeCopySigningInformation(staticCode, options, &information) == errSecSuccess
 +        else { return nil }
 +        return (information as? [String: Any])?[kSecCodeInfoUnique as String] as? Data
++=======
+     static func isTrusted(_ bundleURL: URL) -> Bool {
+         var staticCode: SecStaticCode?
+         guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
+             let staticCode
+         else { return false }
+         // An unsealed bundle can claim any identity, and a nested helper is where one hides.
+         let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
+         guard SecStaticCodeCheckValidity(staticCode, flags, nil) == errSecSuccess else { return false }
+         guard let running = runningLeaf(), let candidate = leaf(of: staticCode) else { return false }
+         return running == candidate
+     }
+ 
+     private static func runningLeaf() -> Data? {
+         var code: SecCode?
+         guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
+         var staticCode: SecStaticCode?
+         guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
+             return nil
+         }
+         return leaf(of: staticCode)
+     }
+ 
+     private static func leaf(of code: SecStaticCode) -> Data? {
+         var information: CFDictionary?
+         let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
+         guard SecCodeCopySigningInformation(code, flags, &information) == errSecSuccess,
+             let dictionary = information as? [String: Any],
+             let certificates = dictionary[kSecCodeInfoCertificates as String] as? [SecCertificate],
+             let leaf = certificates.first
+         else { return nil }
+         return SecCertificateCopyData(leaf) as Data
++>>>>>>> theirs
      }
  }
```

</details>

<!-- cause: 0003-edition-identity: Tinycast/Features/Updates/Model/ReleaseFeed.swift Tinycast/Features/Updates/Service/BundleSignature.swift -->
