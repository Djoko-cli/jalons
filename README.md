# Jalons

[English](#english) · [Français](#français)

---

## English

**Jalons shows where a project's roadmap stands, all the time:** a menu bar item with the current phase and its progress, and a floating timeline that checks itself off as the work gets done.

It **reads and never writes.** The roadmap comes from a design spec and its plans, in Markdown, and Jalons updates within half a second of any change on disk. The interface is in French.

### What it reads

- **Phases:** the checkboxes of the spec whose label starts with `Phase N`, for example `- [ ] Phase 1: foundation` or `- [x] Phase 2 — inventory`. A checked box means the phase is done.
- **Tasks:** the plans in the `plans/` folder next to the spec's folder (`docs/superpowers/specs/x.md` → `docs/superpowers/plans/`).
  - A plan belongs to phase N when its file name contains `phase-N`, for example `2026-10-16-phase-1-foundation.md`.
  - Its tasks are its `### Task N` headings, and their checkboxes are its steps. Plans are read with the plan parser of Orchestre.

### How progress is computed

- A phase checked in the roadmap counts for 100 %. Otherwise it counts for the share of checked steps in its plans, or 0 % without a plan.
- Overall progress is the average of the phases: every phase weighs the same.
- The current phase is the first unchecked one, in file order.

### Incomplete reads are never hidden

Jalons reports these cases in plain words:

- an unreadable plan or plans folder;
- a plan that no phase claims: no `phase-N` in its name, or a number that is not in the roadmap;
- a `Phase` checkbox that was not kept: `Phase 1.1`, or a duplicate number.

They show up in the menu, in the timeline, on the menu bar icon (orange triangle) and in its VoiceOver label, and are never shown as "plan to write" or as 0 %.

### Requirements

- macOS 15 or later, with Liquid Glass on macOS 26 and later.
- Swift 6 (Xcode 16 or later).
- The `OrchestreCore` library of Orchestre, in a checkout next to this one (`../orchestre`).

### Build and run

```bash
scripts/build-app.sh
```

```bash
open build/Jalons.app
```

Then choose a spec in the menu: « Choisir une feuille de route… ».

### Tests

```bash
swift test
```

### Debugging options

- `-specPath <path>`: follows this spec without changing the chosen one.
- `-snapshotDir <folder>`: writes `frise.png` (the timeline) and `barre-des-menus.png` (the menu bar icon), without screen recording permission.
- `-quitAfterSnapshot`: quits once the images are written.
- `-appearance light|dark`: forces the appearance.
- `-settingsSuite <name>`: reads and writes the settings in this `UserDefaults` suite.
- `-noWatch`: no file watching.

---

## Français

**Jalons montre en permanence où en est la feuille de route d'un projet :** une icône dans la barre des menus avec la phase en cours et son avancement, et une frise flottante qui se coche au fil du travail.

Elle **lit et n'écrit jamais.** La feuille de route vient d'une spec de conception et de ses plans, en Markdown, et Jalons se met à jour dans la demi-seconde qui suit un changement sur le disque. L'interface est en français.

### Ce qu'elle lit

- **Les phases :** les cases de la spec dont le libellé commence par `Phase N`, par exemple `- [ ] Phase 1 : socle` ou `- [x] Phase 2 — inventaire`. Une case cochée veut dire que la phase est finie.
- **Les tâches :** les plans du dossier `plans/` voisin du dossier de la spec (`docs/superpowers/specs/x.md` → `docs/superpowers/plans/`).
  - Un plan appartient à la phase N quand son nom de fichier contient `phase-N`, par exemple `2026-10-16-phase-1-socle.md`.
  - Ses tâches sont ses titres `### Task N`, et leurs cases sont ses étapes. Les plans sont lus avec le lecteur de plans d'Orchestre.

### Le calcul de l'avancement

- Une phase cochée dans la feuille de route compte pour 100 %. Sinon, elle compte pour la part des étapes cochées dans ses plans, ou 0 % sans plan.
- L'avancement global est la moyenne des phases : chaque phase pèse pareil.
- La phase en cours est la première non cochée, dans l'ordre du fichier.

### Une lecture incomplète n'est jamais cachée

Jalons signale ces cas en clair :

- un plan ou un dossier des plans illisible ;
- un plan qu'aucune phase ne réclame : pas de `phase-N` dans son nom, ou un numéro absent de la feuille de route ;
- une case `Phase` qui n'a pas été retenue : `Phase 1.1`, ou un numéro en double.

Ils apparaissent dans le menu, dans la frise, sur l'icône de la barre des menus (triangle orange) et dans son libellé VoiceOver, et ne passent jamais pour un « plan à écrire » ni pour un 0 %.

### Prérequis

- macOS 15 ou plus récent, avec Liquid Glass à partir de macOS 26.
- Swift 6 (Xcode 16 ou plus récent).
- La bibliothèque `OrchestreCore` d'Orchestre, dans une copie voisine de celle-ci (`../orchestre`).

### Compiler et lancer

```bash
scripts/build-app.sh
```

```bash
open build/Jalons.app
```

Choisis ensuite une spec dans le menu : « Choisir une feuille de route… ».

### Tests

```bash
swift test
```

### Options de mise au point

- `-specPath <chemin>` : suit cette spec sans changer celle qui est choisie.
- `-snapshotDir <dossier>` : écrit `frise.png` (la frise) et `barre-des-menus.png` (l'icône de la barre des menus), sans autorisation d'enregistrement d'écran.
- `-quitAfterSnapshot` : quitte une fois les images écrites.
- `-appearance light|dark` : force l'apparence.
- `-settingsSuite <nom>` : lit et écrit les réglages dans cette suite de `UserDefaults`.
- `-noWatch` : aucune surveillance des fichiers.
