# Notes de version / Release notes

## 0.3.0

### English

- **Working copies:** Jalons also reads the plans of the repository's other working copies (`git worktree`), so a plan executed in a copy shows its progress before it is merged back. For each plan, the version with the most steps done or deferred wins; a plan found only in another copy joins its phase, with a branch glyph and the copy's branch. A copy added or removed is noticed at once.

### Français

- **Copies de travail :** Jalons lit aussi les plans des autres copies de travail du dépôt (`git worktree`) : un plan exécuté dans une copie montre son avancement avant de remonter. Pour chaque plan, la version qui a le plus d'étapes faites ou reportées l'emporte ; un plan qui n'existe que dans une autre copie rejoint sa phase, avec un glyphe de branche et le nom de la branche de sa copie. Une copie ajoutée ou retirée se voit aussitôt.

## 0.2.0

### English

- **Steps in the timeline:** the next task of the current phase shows its steps, with the next step highlighted; the other tasks unfold with their chevron. The menu shows the next step under the next task.
- **Several timelines at once:** Jalons follows a list of roadmaps, each with its own floating timeline, placed and shown on its own. The menu bar icon shows the main one; the menu lists them all, with their commands. The single roadmap followed before is carried over.
- **Deferred steps:** a step written `- [-]` (postponed to another phase, replaced or no longer relevant) is shown as such, stays out of the progress count and is never the next step: a task with only deferred steps left is done, and a phase in that case awaits sign-off.
- **App icon:** a surveyor's stake, vermilion on cream. The build stops if the icon is missing.

### Français

- **Les étapes dans la frise :** la prochaine tâche de la phase en cours montre ses étapes, avec la suivante mise en avant ; les autres tâches se déplient par leur chevron. Le menu montre l'étape suivante sous la prochaine tâche.
- **Plusieurs frises en même temps :** Jalons suit une liste de feuilles de route, chacune avec sa frise flottante, placée et affichée séparément. L'icône de la barre des menus montre la principale ; le menu les liste toutes, avec leurs commandes. La feuille de route suivie jusque-là est reprise.
- **Étapes reportées :** une étape écrite `- [-]` (reportée à une autre phase, remplacée ou sans objet) est montrée comme telle, reste hors du compte de l'avancement et n'est jamais la prochaine étape : une tâche dont il ne reste que des étapes reportées est faite, et une phase dans ce cas est à valider.
- **Icône de l'app :** un jalon d'arpenteur, vermillon sur crème. La construction s'arrête si l'icône manque.

## 0.1.0

### English

- First version: the menu bar item and the floating timeline of one roadmap.

### Français

- Première version : l'icône de la barre des menus et la frise flottante d'une feuille de route.
