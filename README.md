# Jalons

[English](#english) · [Français](#français)

---

## English

**Jalons shows where a project's roadmap stands, all the time:** a menu bar item with the current phase and its progress, and a floating timeline that checks itself off as the work gets done.

It can **follow several roadmaps at once**, each with its own floating timeline that you place and show or hide on its own. The menu bar icon shows the main one; the menu lists them all, each with its commands (show the timeline, make it the main one, open the spec, stop following it).

It **reads and never writes.** The roadmap comes from a design spec and its plans, in Markdown, and Jalons updates within half a second of any change on disk. If file watching cannot start, Jalons says so and re-reads every minute. The interface is in French.

### What it reads

- **Phases:** the checkboxes of the spec whose label starts with `Phase N`, for example `- [ ] Phase 1: foundation` or `- [x] Phase 2 — inventory`. A checked box means the phase is done.
- **Tasks:** the plans in the `plans/` folder next to the spec's folder (`docs/superpowers/specs/x.md` → `docs/superpowers/plans/`).
  - A plan belongs to phase N when its file name contains `phase-N`, for example `2026-10-16-phase-1-foundation.md`.
  - Its tasks are its `### Task N` (or `### Tâche N`) headings, and the checkboxes under them are its steps. Checkboxes outside any task count as steps too. Plans are read by the `PlanParsing` module (`Sources/PlanParsing`), the plan parser of Orchestre, another tool by the same author, copied here so that Jalons builds on its own.
  - A step marked `- [-]` is **deferred**: postponed to another phase, replaced, or no longer relevant (say why in the text after the box). It is shown as such, neither done nor left: it stays out of the progress count, a task with only deferred steps left is done, and the next step is never a deferred one.
- **Other working copies:** when the spec lives in a git repository, Jalons also reads the same `plans/` folder in every other working copy of the repository (`git worktree`), where a plan often moves forward before it is merged back. For each plan file, it keeps the version with the most steps done or deferred (on a tie, the followed spec's own); a plan found only in another copy joins its phase. Every plan read in another copy, whether its version won or it exists only there, shows a branch glyph with the copy's branch (or the copy's folder name, for a detached copy), and the menu adds « (copie de travail) » to its tasks. Copies are read from git's own files, without running git, and a copy added or removed is noticed at once.

### How progress is computed

- A phase checked in the roadmap counts for 100 %. Otherwise it counts for the share of checked steps in its plans, or 0 % without a plan.
- Overall progress is the average of the phases: every phase weighs the same.
- The current phase is the first unchecked one, in file order.

### Incomplete reads are never hidden

Jalons reports these cases in plain words:

- an unreadable plan or plans folder;
- a plan without any checkbox;
- a plan that no phase claims: no `phase-N` in its name, or a number that is not in the roadmap;
- a `Phase` checkbox that was not kept: `Phase 1.1`, or a duplicate number;
- an HTML comment never closed in the spec, which hides the rest of it.

They show up in the menu, in the timeline, on the menu bar icon (orange triangle) and in its VoiceOver label. A phase whose progress cannot be measured (unreadable plan or plans folder, plan without checkboxes) shows `?` instead of a percentage, never 0 %. A plan that no phase claims is listed in the warnings, but the phase it was meant for still shows "plan to write": Jalons cannot know which one it was.

### Install

Download `Jalons-X.Y.Z.zip` from the [Releases](https://github.com/Djoko-cli/jalons/releases) page, unzip it and move `Jalons.app` to the Applications folder. It is signed with an Apple Developer ID and notarized, so it opens without a Gatekeeper warning.

### Requirements

- The app runs on a Mac with Apple silicon, on macOS 15 or later, with Liquid Glass on macOS 26 and later.
- Building it takes Swift 6 and the macOS 26 SDK (Xcode 26 or later), for the Liquid Glass APIs.

### Build and run

```bash
scripts/build-app.sh
```

```bash
open build/Jalons.app
```

Then add one or more specs in the menu: « Ajouter une feuille de route… ». The first one added is the main one.

The script compiles the app icon (`Ressources/AppIcon.icon`, an Icon Composer file) with `actool`, and stops if the icon is missing. Its only layer is drawn by a script: `swift scripts/dessiner-icone.swift Ressources/AppIcon.icon/Assets/jalon.png`.

### Tests

```bash
swift test
```

The publishing tool has its own tests:

```bash
python3 -m unittest discover -s scripts/tests
```

### Publishing a version

```bash
bash scripts/publier.sh X.Y.Z
```

It builds `Jalons-X.Y.Z.zip` and its `SHA256SUMS` in `build/publication/X.Y.Z/`. Run it from a full clone, with a clean tree and `VERSION` set to X.Y.Z in `scripts/build-app.sh`. In order, it:

- runs the tool's tests;
- signs the app with the only « Developer ID Application » identity of the keychain (hardened runtime, timestamp);
- has it notarized with the `notarytool` keychain profile named by `PROFIL_NOTARISATION`, staples the ticket and checks it with Gatekeeper;
- refuses to deliver an archive that holds a personal path or a value of `garde.local.txt`. The check reads a copy stripped of its signatures.

`--repetition` rehearses the same chain under the identifier `io.github.djoko-cli.jalons.repetition`; only a rehearsal may sign ad hoc (`IDENTITE_SIGNATURE=-`) or skip notarization (`NOTARISER=0`). The tool comes from macstatusd, by the same author.

### Leak guard

This repository may become public, so `.githooks/` holds a guard that refuses a commit or a push that would leak a real identifier: private, Tailscale or link-local IPv4 addresses, IPv6 ULA or global addresses, MAC addresses, Tailscale host names, `/Users/<name>` paths, and the values of a local list. It examines file names, added lines (binary files included), commit messages, author, committer and tagger names, annotated tags, the names of pushed branches and tags, and the pushed head (file names, and contents against the local list). When it cannot read what it must examine, it refuses.

- Install it once per clone, and again after each update of `.githooks/`: `.githooks/essai-garde.sh --installe`. It copies the guard into `.git/hooks`, so it still runs on an older branch, in a `git worktree` and after the repository is moved.
- Create `garde.local.txt` at the root of the repository (ignored by git, never shared): one real value per line (names, rooms, devices, network names…), written with its accents. Empty lines and lines starting with `#` are ignored, and a value is found whatever its case and accents. A `git worktree` uses the list of the main repository. Without the list, every commit is refused.
- The push check is the one that counts: `rebase`, `cherry-pick`, `am` and `merge` skip the commit check, and `git commit -m` keeps the lines that start with `#`. Push with the `git` command line: an app that does not call `git` skips the hooks. To tell new commits from published ones, the push check asks the remote for its branches (`git ls-remote`); without an answer, it examines the whole pushed history.
- It needs `perl` with the `Encode` and `Unicode::Normalize` modules (shipped with macOS).
- `.githooks/essai-garde.sh` replays the guard's scenarios on throwaway repositories, and `.githooks/essai-garde.sh --historique` runs the push check over the whole history of the repository.
- In tests and examples, use only made-up values: `192.0.2.x`, `2001:db8::1`, `fd00::1`, `02:00:00:00:00:01`. Never bypass the guard with `--no-verify`.

### Debugging options

- `-specPath <path>`: follows only this spec, and shows its timeline, without changing the followed list.
- `-snapshotDir <folder>`: writes `frise.png` (the main timeline, then `frise-2.png`, `frise-3.png`… for the others) and `barre-des-menus.png` (the menu bar icon), without screen recording permission.
- `-quitAfterSnapshot`: quits once the images are written.
- `-appearance light|dark`: forces the appearance of the snapshots (with `-snapshotDir`).
- `-settingsSuite <name>`: reads and writes the settings in this `UserDefaults` suite.
- `-noWatch`: no file watching.

### Limits

- The `plans/` folder belongs to the followed spec. In a repository where several specs share it, their plans show up as unattached, and a plan of another spec named `phase-N` is counted in phase N.
- For a spec stored outside a `…/specs/` folder, Jalons watches the folder above the spec's folder, which can be broad.
- Other working copies count until they are removed (`git worktree remove`): an abandoned copy that kept a more advanced plan still shows it, with its branch glyph.
- Versions of a plan are matched by file name: a plan renamed in another copy counts as a second plan. When versions have as many steps done, the followed spec's wins, even if another copy's has more steps.
- A plan from another copy whose checkboxes all sit outside any task counts in the progress but shows no glyph, since the timeline lists tasks.
- For a submodule, or a repository made with `--separate-git-dir`, a spec followed in an added copy does not see the main checkout.

---

## Français

**Jalons montre en permanence où en est la feuille de route d'un projet :** une icône dans la barre des menus avec la phase en cours et son avancement, et une frise flottante qui se coche au fil du travail.

Elle peut **suivre plusieurs feuilles de route à la fois**, chacune avec sa propre frise flottante, que tu places, affiches ou masques séparément. L'icône de la barre des menus montre la principale ; le menu les liste toutes, chacune avec ses commandes (afficher la frise, en faire la principale, ouvrir la spec, ne plus la suivre).

Elle **lit et n'écrit jamais.** La feuille de route vient d'une spec de conception et de ses plans, en Markdown, et Jalons se met à jour dans la demi-seconde qui suit un changement sur le disque. Si la surveillance des fichiers ne peut pas démarrer, Jalons le dit et relit les fichiers chaque minute. L'interface est en français.

### Ce qu'elle lit

- **Les phases :** les cases de la spec dont le libellé commence par `Phase N`, par exemple `- [ ] Phase 1 : socle` ou `- [x] Phase 2 — inventaire`. Une case cochée veut dire que la phase est finie.
- **Les tâches :** les plans du dossier `plans/` voisin du dossier de la spec (`docs/superpowers/specs/x.md` → `docs/superpowers/plans/`).
  - Un plan appartient à la phase N quand son nom de fichier contient `phase-N`, par exemple `2026-10-16-phase-1-socle.md`.
  - Ses tâches sont ses titres `### Task N` (ou `### Tâche N`), et les cases placées sous eux sont ses étapes. Les cases hors de toute tâche comptent aussi comme étapes. Les plans sont lus par le module `PlanParsing` (`Sources/PlanParsing`) : le lecteur de plans d'Orchestre, un autre outil du même auteur, copié ici pour que Jalons se compile seul.
  - Une étape marquée `- [-]` est **reportée** : renvoyée à une autre phase, remplacée ou devenue sans objet (la raison s'écrit dans le texte après la case). Elle est affichée comme telle, ni faite ni à faire : elle reste hors du compte de l'avancement, une tâche dont il ne reste que des étapes reportées est faite, et la prochaine étape n'est jamais une étape reportée.
- **Les autres copies de travail :** quand la spec est dans un dépôt git, Jalons lit aussi le même dossier `plans/` dans chacune des autres copies de travail du dépôt (`git worktree`), où un plan avance souvent avant de remonter. Pour chaque fichier de plan, il retient la version qui a le plus d'étapes faites ou reportées (à égalité, celle de la spec suivie) ; un plan qui n'existe que dans une autre copie rejoint sa phase. Tout plan lu dans une autre copie, que sa version l'ait emporté ou qu'il n'existe que là, porte un glyphe de branche avec la branche de sa copie (ou le nom de son dossier, pour une copie en tête détachée), et le menu ajoute « (copie de travail) » à ses tâches. Les copies se lisent dans les fichiers de git, sans le lancer, et une copie ajoutée ou retirée se voit aussitôt.

### Le calcul de l'avancement

- Une phase cochée dans la feuille de route compte pour 100 %. Sinon, elle compte pour la part des étapes cochées dans ses plans, ou 0 % sans plan.
- L'avancement global est la moyenne des phases : chaque phase pèse pareil.
- La phase en cours est la première non cochée, dans l'ordre du fichier.

### Une lecture incomplète n'est jamais cachée

Jalons signale ces cas en clair :

- un plan ou un dossier des plans illisible ;
- un plan sans aucune case ;
- un plan qu'aucune phase ne réclame : pas de `phase-N` dans son nom, ou un numéro absent de la feuille de route ;
- une case `Phase` qui n'a pas été retenue : `Phase 1.1`, ou un numéro en double ;
- un commentaire HTML jamais refermé dans la spec, qui en cache la suite.

Ils apparaissent dans le menu, dans la frise, sur l'icône de la barre des menus (triangle orange) et dans son libellé VoiceOver. Une phase dont l'avancement ne se mesure pas (plan ou dossier des plans illisible, plan sans case) affiche `?` au lieu d'un pourcentage, jamais 0 %. Un plan qu'aucune phase ne réclame figure dans les avertissements, mais la phase à laquelle il était destiné affiche toujours « plan à écrire » : Jalons ne peut pas savoir laquelle c'était.

### Installer

Télécharge `Jalons-X.Y.Z.zip` depuis la page [Releases](https://github.com/Djoko-cli/jalons/releases), décompresse-le et place `Jalons.app` dans le dossier Applications. Elle est signée par un Developer ID d'Apple et notarisée : elle s'ouvre sans alerte de Gatekeeper.

### Prérequis

- L'app tourne sur un Mac à puce Apple, sous macOS 15 ou plus récent, avec Liquid Glass à partir de macOS 26.
- Pour la compiler, il faut Swift 6 et le SDK de macOS 26 (Xcode 26 ou plus récent), pour les API de Liquid Glass.

### Compiler et lancer

```bash
scripts/build-app.sh
```

```bash
open build/Jalons.app
```

Ajoute ensuite une ou plusieurs specs dans le menu : « Ajouter une feuille de route… ». La première ajoutée est la principale.

Le script compile l'icône de l'app (`Ressources/AppIcon.icon`, un fichier Icon Composer) avec `actool`, et s'arrête si elle manque. Son unique calque est dessiné par un script : `swift scripts/dessiner-icone.swift Ressources/AppIcon.icon/Assets/jalon.png`.

### Tests

```bash
swift test
```

L'outil de publication a ses propres tests :

```bash
python3 -m unittest discover -s scripts/tests
```

### Publier une version

```bash
bash scripts/publier.sh X.Y.Z
```

Il produit `Jalons-X.Y.Z.zip` et son `SHA256SUMS` dans `build/publication/X.Y.Z/`. Lance-le depuis un clone complet, avec un arbre propre et `VERSION` à X.Y.Z dans `scripts/build-app.sh`. Dans l'ordre, il :

- lance les tests de l'outil ;
- signe l'app avec la seule identité « Developer ID Application » du trousseau (runtime renforcé, horodatage) ;
- la fait notariser avec le profil de trousseau de `notarytool` nommé par `PROFIL_NOTARISATION`, agrafe le ticket et la fait vérifier par Gatekeeper ;
- refuse de livrer une archive qui contient un chemin personnel ou une valeur de `garde.local.txt`. Le contrôle lit une copie dépouillée de ses signatures.

`--repetition` répète la même chaîne sous l'identifiant `io.github.djoko-cli.jalons.repetition` ; seule une répétition peut signer en ad hoc (`IDENTITE_SIGNATURE=-`) ou se passer de la notarisation (`NOTARISER=0`). L'outil vient de macstatusd, du même auteur.

### Garde anti-fuite

Ce dépôt peut devenir public. Son dossier `.githooks/` contient un garde qui refuse tout commit ou push qui laisserait fuir un identifiant réel : adresses IPv4 privées, Tailscale ou de lien local, adresses IPv6 ULA ou globales, adresses MAC, noms d'hôte Tailscale, chemins `/Users/<nom>` et valeurs d'une liste locale. Il examine les noms de fichiers, les lignes ajoutées (binaires compris), les messages de commit, les noms d'auteur, de committer et de tagger, les tags annotés, les noms des branches et des tags poussés, et la tête poussée (noms de fichiers, et contenu comparé à la liste locale). Quand il ne peut pas lire ce qu'il doit examiner, il refuse.

- L'installer une fois par clone, puis après chaque mise à jour de `.githooks/` : `.githooks/essai-garde.sh --installe`. Il copie le garde dans `.git/hooks` : il agit encore sur une ancienne branche, dans une copie `git worktree` et après un déplacement du dépôt.
- Créer `garde.local.txt` à la racine du dépôt (ignoré par git, jamais partagé) : une valeur réelle par ligne (noms, pièces, appareils, noms de réseau…), écrite avec ses accents. Les lignes vides et celles qui commencent par `#` sont ignorées, et une valeur est trouvée quelles que soient sa casse et ses accents. Une copie `git worktree` se sert de la liste du dépôt principal. Sans liste, tout commit est refusé.
- C'est le contrôle du push qui compte : `rebase`, `cherry-pick`, `am` et `merge` sautent celui du commit, et `git commit -m` garde les lignes qui commencent par `#`. Pousser avec `git` en ligne de commande : une app qui n'appelle pas `git` saute les crochets. Pour distinguer les commits neufs des commits publiés, le contrôle du push demande ses branches au dépôt distant (`git ls-remote`) ; sans réponse, il examine tout l'historique poussé.
- Il faut `perl`, avec les modules `Encode` et `Unicode::Normalize` (fournis avec macOS).
- `.githooks/essai-garde.sh` rejoue les scénarios du garde sur des dépôts jetables, et `.githooks/essai-garde.sh --historique` passe le contrôle du push sur tout l'historique du dépôt.
- Dans les tests et les exemples, seulement des valeurs inventées : `192.0.2.x`, `2001:db8::1`, `fd00::1`, `02:00:00:00:00:01`. Ne jamais contourner le garde par `--no-verify`.

### Options de mise au point

- `-specPath <chemin>` : suit cette seule spec, et affiche sa frise, sans changer la liste suivie.
- `-snapshotDir <dossier>` : écrit `frise.png` (la frise principale, puis `frise-2.png`, `frise-3.png`… pour les autres) et `barre-des-menus.png` (l'icône de la barre des menus), sans autorisation d'enregistrement d'écran.
- `-quitAfterSnapshot` : quitte une fois les images écrites.
- `-appearance light|dark` : force l'apparence des images (avec `-snapshotDir`).
- `-settingsSuite <nom>` : lit et écrit les réglages dans cette suite de `UserDefaults`.
- `-noWatch` : aucune surveillance des fichiers.

### Limites

- Le dossier `plans/` appartient à la spec suivie. Dans un dépôt où plusieurs specs le partagent, leurs plans apparaissent comme non rattachés, et le plan d'une autre spec nommé `phase-N` est compté dans la phase N.
- Pour une spec rangée hors d'un dossier `…/specs/`, Jalons surveille le dossier situé au-dessus de celui de la spec, ce qui peut être large.
- Les autres copies de travail comptent jusqu'à leur suppression (`git worktree remove`) : une copie abandonnée qui garde un plan plus avancé le montre toujours, avec son glyphe de branche.
- Les versions d'un plan se rapprochent par leur nom de fichier : un plan renommé dans une autre copie compte comme un second plan. À nombre égal d'étapes faites, la version de la spec suivie l'emporte, même si celle d'une autre copie a plus d'étapes.
- Un plan d'une autre copie dont toutes les cases sont hors de toute tâche compte dans l'avancement mais ne porte pas de glyphe, puisque la frise liste les tâches.
- Pour un sous-module, ou un dépôt créé avec `--separate-git-dir`, une spec suivie dans une copie ajoutée ne voit pas la copie principale.
