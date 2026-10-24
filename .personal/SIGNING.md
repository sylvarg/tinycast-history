# Signature de l'édition

L'édition est signée avec une **identité auto-signée stable**, nommée comme celle du projet original
— `Tinycast Self-Signed` — pour rester compatible avec `project.yml` et `Scripts/`, mais avec **sa
propre clé**. Aucun abonnement Apple Developer n'est nécessaire et la notarisation n'est pas requise.

Garder *la même* identité d'une version à l'autre est indispensable :

- macOS conserve l'autorisation **Accessibilité** tant que la signature désignée (identifiant +
  certificat) ne change pas ;
- le programme de mise à jour n'installe qu'une app dont le certificat feuille est identique à celui
  de l'app en cours ; une autre identité laisserait toutes les copies installées sans mise à jour ;
- les clés des historiques chiffrés sont accessibles, sans invite, à l'app qui satisfait cette même
  signature désignée.

`build-release.sh` refuse de publier si l'app n'est pas signée par le secret, ou par un certificat
différent de celui de la release précédente.

## Créer l'identité (une seule fois, sur votre Mac)

Dans Terminal, depuis une copie de ce dépôt (ou en téléchargeant seulement ce script) :

```sh
.personal/signing/create-identity.sh            # écrit dans ~/Desktop/tinycast-signing
```

Le script n'utilise que `/usr/bin/openssl` ; il ne lit ni n'exporte rien de votre trousseau. Il crée,
dans un dossier lisible par vous seul :

| Fichier | Usage |
| --- | --- |
| `tinycast-signing.p12` | l'identité (clé privée + certificat). **À sauvegarder** hors ligne |
| `SIGNING_P12_PASSWORD.txt` | son mot de passe, à conserver avec la sauvegarde (gestionnaire de mots de passe) |
| `SIGNING_P12_BASE64.txt` | valeur du secret `SIGNING_P12_BASE64` |
| `certificate.sha256` | empreinte publique, affichée dans chaque release pour comparaison |

Puis, sur GitHub : **sylvarg/tinycast-history › Settings › Secrets and variables › Actions › New
repository secret**, créez `SIGNING_P12_BASE64` (contenu de `SIGNING_P12_BASE64.txt`) et
`SIGNING_P12_PASSWORD` (contenu de `SIGNING_P12_PASSWORD.txt`). Supprimez ensuite les deux fichiers
`.txt` ; gardez `tinycast-signing.p12` et son mot de passe dans votre sauvegarde.

Seule cette identité est exportée : n'utilisez pas `security export -t identities`, qui exporterait
toutes les identités du trousseau. Pour compiler localement (facultatif), importez le `.p12` dans le
trousseau de session : `security import tinycast-signing.p12 -k ~/Library/Keychains/login.keychain-db
-T /usr/bin/codesign` (le mot de passe est demandé). Attention : une copie locale du projet original
installe sa propre identité du même nom ; n'en gardez qu'une.

## Jeton de publication

`PERSONAL_PUSH_TOKEN` : *Settings › Developer settings › Personal access tokens › Fine-grained tokens*,
**Repository access : Only select repositories → sylvarg/tinycast-history**, permissions
**Contents : Read and write** et **Workflows : Read and write** (aucune autre). Il sert uniquement à
pousser `main` régénérée et les tags de release, qui contiennent des modifications de
`.github/workflows` que le `GITHUB_TOKEN` n'a pas le droit de pousser. Expiration recommandée : 1 an,
à renouveler (à l'expiration, la synchro échoue avec une erreur d'authentification et GitHub vous envoie le mail d'échec).

## Si un secret est perdu

- **Secrets GitHub perdus, `.p12` conservé** : recréez les deux secrets depuis la sauvegarde ;
  rien ne change pour les copies installées.
- **Identité perdue** : créez-en une nouvelle (le script refuse d'écraser un `.p12` existant ;
  déplacez l'ancien dossier). `build-release.sh` bloquera la publication tant que la release
  précédente porte l'ancien certificat : supprimez manuellement ce contrôle pour une seule release de
  transition, documentez-la, puis réinstallez-la à la main sur chaque Mac (le programme de mise à jour
  des anciennes copies la refusera), réautorisez Accessibilité, et autorisez l'accès aux clés des
  historiques chiffrés quand macOS le demande.

## Clés de données ≠ signature

Les clés qui chiffrent les historiques sont créées sur chaque Mac, dans le trousseau de session de
l'utilisateur, et n'en sortent jamais : elles ne sont ni dans le dépôt, ni dans les secrets, ni dans
les builds. Le certificat de signature, lui, n'est qu'une identité de code ; il ne chiffre rien.
