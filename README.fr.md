# Tinycast — édition personnelle avec historique

*[English](README.md) · Français*

**Édition personnelle, publique et non officielle** de [Tinycast](https://github.com/abue-ammar/tinycast),
le lanceur macOS d'Abue Ammar. Elle reste l'application **Tinycast** (`Tinycast.app`,
`com.tinycast.app`), remplace l'installation officielle et reprend ses réglages et données, et ajoute
une seule fonctionnalité : **rappeler avec ↑ les saisies validées du lanceur**.

> Ce dépôt n'est pas le projet officiel et n'est pas soutenu par son auteur. La demande d'origine,
> [abue-ammar/tinycast#1570](https://github.com/abue-ammar/tinycast/issues/1570) « Calculator HIstory
> (or Launcher history in general) », a été **fermée comme `not_planned`** le 14 octobre 2026 : le
> mainteneur a [décliné](https://github.com/abue-ammar/tinycast/issues/1570#issuecomment-6163760400)
> la maintenance de cet historique, conformément à sa [position sur les personnalisations](https://github.com/abue-ammar/tinycast/issues/1554).
> Cette fonctionnalité appartient donc à cette édition seule ; merci de ne pas la signaler au projet
> original.
>
> L'édition est publiée **telle quelle, pour un usage personnel, sans support** : les issues sont
> désactivées sur ce dépôt et aucun signalement n'y est suivi.

## La fonctionnalité

- Dans le lanceur, champ **vide**, **↑** remet dans le champ la dernière saisie validée, curseur à la
  fin : résultats, carte de calcul, action principale et menu ⌘K se mettent à jour comme si vous
  l'aviez tapée. Chaque ↑ suivant remonte d'une entrée, jusqu'à la plus ancienne (pas de boucle).
- **↓** navigue toujours dans les résultats de la saisie rappelée (puis ↵, ⌘K…). Il n'y a pas de
  retour vers des saisies plus récentes.
- Dès que vous modifiez le texte, ↑ redevient la navigation habituelle ; videz le champ pour
  recommencer depuis la saisie la plus récente.
- Une saisie est enregistrée quand une action est réellement lancée depuis la barre (ouvrir une app,
  une commande, un quicklink, une commande d'extension, une ligne ⌘K, une copie…) **ou** quand un
  résultat de calcul (y compris conversions, fuseaux, dates) ou une carte de couleur est réellement
  affiché — même si vous fermez ensuite avec Échap. Rappeler une entrée ne l'enregistre pas ; la
  valider à nouveau la remonte en tête, sans doublon. Au plus 100 entrées.
- **Clear Launcher History** (commande du lanceur) efface cet historique et sa clé, après confirmation,
  sans toucher à l'historique du presse-papiers ni à celui des calculs.

Détails et limites : [docs/features/launcher-history.md](docs/features/launcher-history.md).

## Protection des données

L'historique (`command-input-history.enc`), **et aussi** l'historique des calculs et les termes de
recherche appris par le lanceur — qui contiennent les mêmes saisies — sont chiffrés sur le disque
(AES-256-GCM, CryptoKit), chacun avec sa propre clé aléatoire conservée uniquement dans **votre
trousseau macOS**, accessible à cette application signée. Les anciens fichiers en clair
(`calculator-history.json`, `launcher-ranking.json`) sont migrés puis supprimés. Les exports de
sauvegarde n'incluent plus ni calculs ni termes de recherche. Cette protection vaut **au repos** :
un fichier copié ou restauré est illisible sans la clé, mais un Mac compromis ou une session
déverrouillée ne sont pas protégés. Les copies faites auparavant (sauvegardes, Time Machine, exports)
ne peuvent pas être effacées rétroactivement. En revenant à la version officielle, ces historiques
repartent vides (elle ne lit pas les fichiers chiffrés).

## Installation (Apple Silicon, macOS 26 ou plus récent)

1. Téléchargez `Tinycast-<version>.dmg` depuis les [releases](https://github.com/sylvarg/tinycast-history/releases)
   et vérifiez si vous le souhaitez son empreinte (`.sha256`).
2. Quittez Tinycast s'il tourne, puis glissez **Tinycast** dans **Applications** en remplaçant la copie
   officielle. Réglages, raccourcis, presse-papiers, notes et snippets sont conservés.
3. L'application est auto-signée (pas de notarisation Apple) : une fois, dans Terminal,
   `xattr -dr com.apple.quarantine /Applications/Tinycast.app` (ou *Réglages Système › Confidentialité
   et sécurité › Ouvrir quand même* au premier lancement).
4. Le certificat diffère de celui de la version officielle : macOS demande à nouveau
   **Accessibilité** (Réglages Système › Confidentialité et sécurité › Accessibilité : retirez l'ancienne
   entrée Tinycast, ajoutez la nouvelle) et, si vous utilisez des fournisseurs d'IA ou MCP, l'accès aux
   clés déjà enregistrées par l'ancienne version (« Toujours autoriser »).
5. À propos de Tinycast affiche **« Édition personnelle avec historique »**, la version officielle de
   base et la révision personnelle.

**Mises à jour** : une fois par jour (réglage *Vérifier automatiquement les mises à jour*, actif par
défaut) ou via *Check for Updates*, l'application consulte les releases de **ce dépôt** et propose la
nouvelle version dans une fenêtre ; après votre accord, elle la télécharge, vérifie l'identifiant, la
version et la signature (certificat identique à celui de l'app installée), l'installe et redémarre. Une version `0.12.1-h.2` corrige `0.12.1-h.1` ; la release officielle suivante arrive
comme `0.12.2-h.1`. Homebrew n'est pas concerné.

**Revenir en arrière** : quittez Tinycast, installez le DMG d'une release précédente de ce dépôt (ou
la version officielle) dans Applications. Une version plus ancienne de cette édition lit les mêmes
fichiers chiffrés ; la version officielle ne les lit pas (historiques vides) et recrée ses fichiers
en clair.

## Construction et maintenance

Tout est construit et testé par GitHub Actions sur macOS ; aucun Xcode local n'est nécessaire.
L'app n'est compilée qu'au moment d'une release : chaque release stable officielle est reconstruite
depuis son tag exact avec les patches de [`.personal/`](.personal/README.md), testée, signée et publiée
ici, puis `main` pointe sur cette source. Une vérification quotidienne, sans compilation, prévient tôt
si les patches ne s'appliquent plus à la branche de développement officielle. Maintenance,
inventaire des modifications du code original et diagnostics : [`.personal/README.md`](.personal/README.md).
Signature : [`.personal/SIGNING.md`](.personal/SIGNING.md). README original : [README.upstream.md](README.upstream.md).

## Crédits et licence

Tinycast est © Abue Ammar et ses contributeurs, sous licence **AGPL-3.0** ([LICENSE](LICENSE),
[NOTICE.md](NOTICE.md)) ; cette édition et ses modifications sont publiées sous la même licence, avec
le code source complet de chaque version (tag `v<version>` et dossier `.personal/patches`). La
mécanique de patches et de publication s'inspire de [Tinycast Space](https://github.com/sermelipharo/tinycast-space)
de sermelipharo ; aucune de ses fonctionnalités n'est reprise.
