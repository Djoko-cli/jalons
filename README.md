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
  - Its tasks are its `### Task N` (or `### Tâche N`) headings, and the checkboxes under them are its steps. Checkboxes outside any task count as steps too. Plans are read with the plan parser of Orchestre.
  - A step marked `- [-]` is **deferred**: postponed to another phase, replaced, or no longer relevant (say why in the text after the box). It is shown as such, neither done nor left: it stays out of the progress count, a task with only deferred steps left is done, and the next step is never a deferred one.

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

### Requirements

- The app runs on macOS 15 or later, with Liquid Glass on macOS 26 and later.
- Building it takes Swift 6 and the macOS 26 SDK (Xcode 26 or later), for the Liquid Glass APIs.
- The `OrchestreCore` library of Orchestre, in a checkout next to this one (`../orchestre`).

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

---

## Français

**Jalons montre en permanence où en est la feuille de route d'un projet :** une icône dans la barre des menus avec la phase en cours et son avancement, et une frise flottante qui se coche au fil du travail.

Elle peut **suivre plusieurs feuilles de route à la fois**, chacune avec sa propre frise flottante, que tu places, affiches ou masques séparément. L'icône de la barre des menus montre la principale ; le menu les liste toutes, chacune avec ses commandes (afficher la frise, en faire la principale, ouvrir la spec, ne plus la suivre).

Elle **lit et n'écrit jamais.** La feuille de route vient d'une spec de conception et de ses plans, en Markdown, et Jalons se met à jour dans la demi-seconde qui suit un changement sur le disque. Si la surveillance des fichiers ne peut pas démarrer, Jalons le dit et relit les fichiers chaque minute. L'interface est en français.

### Ce qu'elle lit

- **Les phases :** les cases de la spec dont le libellé commence par `Phase N`, par exemple `- [ ] Phase 1 : socle` ou `- [x] Phase 2 — inventaire`. Une case cochée veut dire que la phase est finie.
- **Les tâches :** les plans du dossier `plans/` voisin du dossier de la spec (`docs/superpowers/specs/x.md` → `docs/superpowers/plans/`).
  - Un plan appartient à la phase N quand son nom de fichier contient `phase-N`, par exemple `2026-10-16-phase-1-socle.md`.
  - Ses tâches sont ses titres `### Task N` (ou `### Tâche N`), et les cases placées sous eux sont ses étapes. Les cases hors de toute tâche comptent aussi comme étapes. Les plans sont lus avec le lecteur de plans d'Orchestre.
  - Une étape marquée `- [-]` est **reportée** : renvoyée à une autre phase, remplacée ou devenue sans objet (la raison s'écrit dans le texte après la case). Elle est affichée comme telle, ni faite ni à faire : elle reste hors du compte de l'avancement, une tâche dont il ne reste que des étapes reportées est faite, et la prochaine étape n'est jamais une étape reportée.

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

### Prérequis

- L'app tourne sur macOS 15 ou plus récent, avec Liquid Glass à partir de macOS 26.
- Pour la compiler, il faut Swift 6 et le SDK de macOS 26 (Xcode 26 ou plus récent), pour les API de Liquid Glass.
- La bibliothèque `OrchestreCore` d'Orchestre, dans une copie voisine de celle-ci (`../orchestre`).

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
