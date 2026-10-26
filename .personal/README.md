# `.personal` — maintenance de l'édition personnelle

Tout ce qui distingue [`sylvarg/tinycast-history`](https://github.com/sylvarg/tinycast-history) du
projet original [`abue-ammar/tinycast`](https://github.com/abue-ammar/tinycast) tient dans ce dossier.
**`main` est une branche générée** : `personal-sync.yml` la reconstruit comme *commit original +
patches de ce dossier*, un commit par patch (titre tiré du nom du fichier, message tiré de sa ligne
ci-dessous), puis un dernier commit (`personal: launcher history edition on upstream <sha>`) qui
contient ce dossier, le README de l'édition et les réécritures. On ne modifie jamais le code de `main`
à la main : on modifie un patch (voir *Modifier un patch*).

La mécanique reprend celle de [Tinycast Space](https://github.com/sermelipharo/tinycast-space)
(`.space/`, de sermelipharo) : application `--3way`, vérification Linux avant macOS, re-découpage des
patches, signalement unique par cause de blocage. Aucun patch ni aucune fonctionnalité de Tinycast Space n'est repris.
Différences volontaires : tous les contrôles propres à l'édition sont bloquants (pas de tolérance de
`gate.sh`), une release est toujours construite depuis le **tag officiel exact** et numérotée
`v<officiel>-h.<révision>`, et un tag publié n'est jamais déplacé.

## Patches

| Fichier | Rôle |
| --- | --- |
| `patches/0001-sealed-storage.patch` | Stockage chiffré : `SealedEnvelope` (AES-256-GCM, en-tête versionné authentifié) et `SealedFile` (clé par stockage dans le trousseau de session via `KeychainSecretStore`, écriture atomique `0600`, migration vérifiée du fichier en clair, écritures bloquées après un échec de lecture). L'historique des calculs (`CalculatorHistoryStore`) et les termes appris du lanceur (`LauncherRankingStore`, via un paramètre `persistence`) passent par lui ; `BackupComposer` n'exporte plus les calculs ni les termes de recherche. |
| `patches/0002-launcher-history.patch` | L'historique des saisies du lanceur : modèle pur (`LauncherHistory`, `LauncherHistorySession`, `LauncherHistoryUndo`), `LauncherHistoryStore`, `LauncherHistoryCoordinator` possédé par `AppCore`, observateur de la liste, commande *Clear Launcher History*, table de chaînes `PersonalEdition` (8 langues), raccordements d'une ligne listés plus bas, et `docs/features/launcher-history.md`. |
| `patches/0003-edition-identity.patch` | Identité de l'édition : section *Personal edition with history* dans À propos (version officielle de base, révision personnelle, liens de ce dépôt et du projet original), flux de mise à jour sur ce dépôt (`ReleaseFeed.repository`), versions `X.Y.Z-h.N` (`AppVersion.revision`), et le programme de mise à jour ne fait plus confiance à l'équipe Developer ID du projet original. |
| `patches/0004-personal-tests.patch` | Les harnesses de l'édition (`Tests/launcher-history-test.swift`, `sealed-storage-test.swift`, `personal-edition-test.swift`, `personal-signature-probe.swift`), lancés par `.personal/tests/run.sh` et `signing.sh`, jamais par `Scripts/run-tests.sh` d'origine. |

## Fichiers du dossier

| Fichier | Rôle |
| --- | --- |
| `UPSTREAM` | Le commit original à partir duquel `main` a été construit. |
| `apply.sh` | Applique les patches dans l'ordre (`git apply --3way`), régénère le projet Xcode avec XcodeGen quand un patch ajoute un fichier (jamais de patch sur `project.pbxproj`), puis les **réécritures** : lien *Changelog* vers les releases de ce dépôt, suppression des workflows d'origine (site, releases, annonces, triage, miroir), `README.upstream.md` = README d'origine verbatim avec un avertissement, `README.md` = `README.edition.md`. `PERSONAL_COMMIT=1` fait un commit par patch ; `PERSONAL_REFRESH=1` re-découpe chaque patch depuis son commit pour garder des bases de fusion. |
| `check-apply.sh` | La boucle d'application seule, dans un worktree jetable, sans projet Xcode : la vérification Linux trouve un conflit avant de réserver un runner macOS, et écrit le diagnostic (patch, fichiers, commits d'origine qui les ont touchés). |
| `gate.sh` | Contrôles de construction : XcodeGen, build Debug **sans aucun avertissement**, `Scripts/lint.sh`, `tests/run.sh` (bloquant) dans un trousseau jetable, `tests/signing.sh` (bloquant), puis `Scripts/run-tests.sh` d'origine : un harness d'origine ne bloque que s'il échoue à chacune de 3 relances ici **et** passe à chacun de 3 passages sur le commit original pur (cas de `form-input-test`, test de rendu qui échoue sur les runners, et de `file-search-session-test`, dont les délais fixes ratent sur un runner chargé). Les contrôles propres à l'édition, eux, ne sont jamais tolérés. Si la compilation échoue, compile aussi l'original pur : quand lui non plus ne compile pas (par exemple avec un Xcode plus ancien que celui de son auteur), le diagnostic l'attribue à l'original et la synchro attend sa correction. Écrit `gate-cause.txt` et `gate-report.md` pour le diagnostic. |
| `release-plan.sh` | Décide ce que construit le workflow de release : dernier tag stable officiel (ou celui demandé), contenu produit par les patches sur ce tag, révision suivante. |
| `build-release.sh` | Build Release arm64 signé, contrôles (`verify-signature.sh`, autorité `Tinycast Self-Signed`, même certificat que le secret **et** que la release précédente), DMG + ZIP `ditto`, vérification de ce qui a été emballé. |
| `publish-release.sh` | Crée le tag (jamais déplacé), publie en brouillon avec tous les fichiers, vérifie, puis publie comme *latest*. |
| `report.sh` | État de blocage **sans issues** (désactivées sur ce dépôt) : un fichier par type (`sync.md`, `release.md`) sur la branche `personal-status`, plus le résumé du run. Une cause nouvelle fait échouer le run, donc **un seul mail GitHub par cause** ; la même cause est seulement mise à jour, en silence ; le fichier est supprimé au premier passage réussi. |
| `README.edition.md`, `README.edition.fr.md` | Deviennent `README.md` (anglais) et `README.fr.md` sur `main`. |
| `SIGNING.md`, `signing/create-identity.sh` | Identité de signature : création, sauvegarde, secrets. |
| `tests/` | `run.sh` (harnesses + contrôles : pureté des modèles, chaînes, style maison, sauvegardes, raccordements), `signing.sh` (trousseau et signature réels), `keychain-sandbox.sh`, `check-hooks.sh`, `check-strings.py`. |
| `tools/` | `strings.py` (génère `PersonalEdition.xcstrings`), `style.sh` (colonnes et commentaires, règles de `docs/standards.md` que rien ne lint). |

## Inventaire des raccordements au code original

Chaque modification d'un fichier existant, avec sa raison et son risque de conflit. Tout le reste
est dans des fichiers nouveaux. `tests/check-hooks.sh` échoue si un raccordement disparaît.

| Fichier d'origine | Modification | Pourquoi | Risque de conflit |
| --- | --- | --- | --- |
| `Palette/RootPaletteView.swift` | 3 lignes dans le gestionnaire `↑` (après le déplacement des favoris et le contrôle de liste ouverte) | Seul endroit qui connaît le focus du champ, le menu ouvert et le champ d'arguments | **Élevé** : fichier le plus modifié en amont |
| `Palette/RootPaletteView.swift` | 1 ligne dans `activateMenuItem` | Toute ligne du menu ⌘K du lanceur est une validation | Élevé |
| `Features/Launcher/UI/LauncherScreen.swift` | 1 ligne dans `activate(at:)`, 2 lignes `.launcherHistory(...)` sur `LauncherList` | ↵ et clics sur cartes/fichiers/fallbacks ; ce qui est affiché (carte de calcul ou de couleur) | Moyen |
| `Features/Launcher/UI/LauncherCoordinator.swift` | 2 lignes en tête de `launch`, 1 dans `showInFinder`/`restart`/`quit`, 2 dans `runCommand` | Clic sur une ligne, annulation si des arguments manquent, raccourcis ⌘↵/⌘R/⌃⇧Q, commande *Clear* | Moyen |
| `Features/Calculator/UI/CalculatorCoordinator.swift` | 1 ligne dans `putAnswerInSearchBar` et `copyCalculationWithExpression` | ⌘↵ et ⇧⌘↵ sur la carte | Faible |
| `Features/AI/UI/QuickAICoordinator.swift` | 1 ligne dans `ask` | ⇥ et le fallback Quick AI envoient la saisie | Faible |
| `Features/Launcher/Model/CommandID.swift` | 1 cas + nom + symbole | Commande *Clear Launcher History* | Moyen (cas ajoutés en amont au même endroit) |
| `App/AppCore.swift` | coordinateur paresseux, `start()`, `confirm`, `pickVolume`, `prepareForTermination`, `LauncherRankingStore(persistence:)` | Propriétaire unique ; annulation sur confirmation refusée ; ranking scellé | **Élevé** |
| `Features/Calculator/Service/CalculatorHistoryStore.swift` | `SealedFile` à la place de l'URL JSON (4 lignes) | Copie des expressions saisies | Faible |
| `Features/Launcher/Model/LauncherRankingStore.swift` | paramètre `persistence` (typealias de fermetures, pas de nouveau type, pour que ses harnesses d'origine compilent seuls) | Termes de recherche appris | Moyen |
| `Features/Backup/Service/BackupComposer.swift` | termes retirés, calculs non exportés | Archive `.tinycast` en clair | Faible |
| `Platform/KeychainSecretStore.swift` | 1 portée `sealed-storage-keys` | La liste unique des portées du trousseau | Faible |
| `Features/Updates/Model/AppVersion.swift` | `revision` (`-h.N`) | Corrections personnelles entre deux releases officielles | Moyen |
| `Features/Updates/Model/ReleaseFeed.swift` | dépôt | Mises à jour depuis ce dépôt | Faible |
| `Features/Updates/Service/BundleSignature.swift` | appel `satisfiesDeveloperID` retiré, commentaire | Ne plus accepter une build signée par l'équipe du projet original ; la constante reste car `updates-test` d'origine la compile | Faible |
| `Windows/About/AboutView.swift` | 1 ligne `PersonalEditionSection()` | Mention de l'édition | Faible |
| Réécritures (`apply.sh`) | lien *Changelog*, workflows d'origine supprimés, README | Pas de hunk : une ligne déplacée en amont ne crée pas de conflit | — |

Écart assumé : la documentation d'origine n'est pas modifiée (pour ne pas multiplier les conflits).
Ses affirmations remplacées par l'édition : `docs/features/updates.md` et `docs/signing.md` (confiance
Developer ID, dépôt des releases), `docs/features/backup.md` (contenu de *Launcher Learning*),
`docs/features/calculator.md` et `docs/architecture.md` (noms de fichiers JSON). La vérité de
l'édition est dans `docs/features/launcher-history.md` et ce fichier.

## Automatisation

- **`personal-sync.yml`** — toutes les 10 minutes environ (cron, sans garantie de délai) et à la
  demande. Linux : compare `main` d'origine à `UPSTREAM`, puis `check-apply.sh` ; un conflit est
  enregistré dans `personal-status/sync.md` et s'arrête là, sans macOS. Sinon macOS 26 : reconstruit `main`,
  `gate.sh`, puis `git push --force-with-lease=main:<ancien>` ; si `main` a bougé pendant la
  construction (une modification humaine), le résultat est abandonné et le passage suivant repart du
  nouvel état. Un échec n'est jamais annoncé comme une synchronisation.
- **`personal-release.yml`** — aux minutes 17 et 47 de chaque heure et à la demande (tag optionnel).
  Linux : `release-plan.sh`. macOS : patches sur le tag officiel exact, `gate.sh`, build signé,
  publication `v<officiel>-h.<N>`. Une release est refaite seulement si le **contenu** change (le
  re-découpage des patches par la synchro ne compte pas). Un échec laisse la dernière release saine
  en place et l'enregistre dans `personal-status/release.md`.
- **`personal-ci.yml`** — `gate.sh` sur toute poussée vers `claude/**` ou `personal/**`.

### Secrets (Settings › Secrets and variables › Actions)

| Secret | Contenu | Utilisé par |
| --- | --- | --- |
| `SIGNING_P12_BASE64` | identité `Tinycast Self-Signed` en PKCS#12, base64 | release |
| `SIGNING_P12_PASSWORD` | son mot de passe | release |
| `PERSONAL_PUSH_TOKEN` | jeton *fine-grained* limité à **ce seul dépôt**, permissions **Contents: Read and write** et **Workflows: Read and write** (nécessaire car les commits d'origine touchent `.github/workflows`) | sync (pousser `main`), release (pousser le tag) |

Les clés qui chiffrent les historiques **ne sont pas** des secrets de CI : elles naissent sur le Mac
de l'utilisateur et n'en sortent pas. Voir [`SIGNING.md`](SIGNING.md) pour l'identité de signature.

## Être prévenu et lire un diagnostic

- **Mail de GitHub** : un run en échec envoie le mail « Run failed » au compte qui a lancé ou programmé
  le workflow. Comme `report.sh` ne fait échouer le run que pour une **cause nouvelle**, un blocage qui
  persiste n'envoie pas un mail toutes les 10 minutes. Réglage : *GitHub › Settings › Notifications
  › Actions* (« Only notify for failed workflows »).
- **Branche `personal-status`** : tant qu'un blocage existe, `sync.md` ou `release.md` contient son
  titre (`… blocked: upstream <sha> + main <sha>`), le lien vers le run et, pour un conflit, le patch,
  les fichiers et les commits d'origine qui les ont touchés depuis le dernier `UPSTREAM` ; pour un échec
  de build ou de test, les contrôles en échec et les premières erreurs. Le fichier disparaît au premier
  passage réussi. La même combinaison n'est pas retentée tant qu'elle est enregistrée.
- **Résumé du run** (onglet *Actions*) : le même diagnostic.
- **Onglet Actions** : l'historique des runs ; un run vert « avec avertissement » signale un blocage
  déjà connu.

## Modifier un patch

Partir de `main` à jour : chaque patch y est un commit (`personal 0002: launcher history`, …).

```sh
git switch -c fix main
# corriger le code, puis amender le commit du patch concerné (rebase interactif ou fixup)
git diff --full-index <commit>~1 <commit> -- . ':!Tinycast.xcodeproj' > .personal/patches/0002-launcher-history.patch
.personal/check-apply.sh "$(cat .personal/UPSTREAM)" "" /tmp/r.md   # tous les patches s'appliquent ?
git switch main && git checkout fix -- .personal && git commit -m "…" && git push
```

La synchro suivante reconstruit `main` avec le patch modifié ; la release suivante publie la
révision `-h.N+1` du même socle. Règles : nouveau code dans de nouveaux fichiers, raccordements d'une
ligne, ajouter plutôt que réécrire, jamais de patch sur `project.pbxproj` ni sur un fichier généré.

## Intégrer une nouvelle release officielle

Rien à faire quand les patches s'appliquent : la release suivante construit `v<nouvelle>-h.1`
depuis le tag. En cas de conflit (mail, `personal-status/sync.md`) :

1. Lire le diagnostic : quels commits d'origine ont touché les lignes ?
2. Si l'original fournit désormais ce que fait un patch (par exemple un historique officiel),
   **retirer** le patch ou sa partie devenue inutile, en gardant la lecture des données existantes
   (fichiers `.enc`, clés) et en documentant la migration ; ne jamais garder deux implémentations.
3. Sinon refaire le raccordement sur le nouveau code (voir *Modifier un patch*), pousser sur `main`.
4. Vérifier que `personal-sync` puis `personal-release` passent ; l'état de blocage s'efface seul.

## Numérotation et mises à jour

`v0.12.1-h.1` = révision 1 de l'édition sur l'officielle 0.12.1. `AppVersion` ordonne
`0.12.1 < 0.12.1-h.1 < 0.12.1-h.2 < 0.12.2 < 0.12.2-h.1` ; une révision n'est pas une pré-release.
L'app installée ne propose que des releases de ce dépôt, pour `com.tinycast.app`, arm64, dont la
signature est valide (y compris l'assistant imbriqué) et dont le certificat feuille est **octet pour
octet** celui de l'app en cours. Une release signée par un autre certificat, dont celles du projet
original, n'est jamais installée.
