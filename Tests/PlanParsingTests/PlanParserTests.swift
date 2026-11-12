// Copie du lecteur de plans d'Orchestre (OrchestreCore/Work, commit d03903e), pour que Jalons se compile seul.
// Une évolution d'un côté se reporte à la main de l'autre.

import Foundation
import Testing
@testable import PlanParsing

@Suite struct PlanParserTests {
    @Test func readsTasksCheckboxesAndFiles() {
        let plan = PlanParser.parse("""
        # Mon plan

        Introduction.

        - [x] case hors tâche

        ### Task 1: Le composant `liste`

        **Files:**
        - Create: `components/liste/liste.c`, `components/liste/include/liste.h`
        - Modify: `tests/lancer.sh:12-40`
        - Test: `tests/test_liste.c`

        **Interfaces:**
        - Create: `pas/un/fichier.c`

        - [ ] **Step 1**
        - [x] **Step 2**

        #### Sous-titre qui ne ferme pas la tâche

        - [ ] **Step 3**

        ### Tâche 2 — Sans fichiers

        - [X] fait

        ## Annexe

        - [ ] case d'annexe
        """)
        #expect(plan.title == "Mon plan")
        #expect(plan.tasks.count == 2)
        let one = plan.tasks[0]
        #expect(one.number == 1)
        #expect(one.title == "Le composant `liste`")
        #expect(one.line == 7)
        #expect(one.checked == 1 && one.total == 3)
        #expect(one.createdFiles == ["components/liste/liste.c", "components/liste/include/liste.h"])
        #expect(one.touchedFiles == ["components/liste/liste.c", "components/liste/include/liste.h", "tests/lancer.sh", "tests/test_liste.c"])
        let two = plan.tasks[1]
        #expect(two.number == 2)
        #expect(two.title == "Sans fichiers")
        #expect(two.checked == 1 && two.total == 1)
        #expect(two.touchedFiles.isEmpty)
        #expect(plan.looseChecked == 1 && plan.looseTotal == 2)
        #expect(plan.anyChecked)
    }

    @Test func keepsEachStepTextStateAndLine() {
        let plan = PlanParser.parse("""
        # Plan

        - [ ] case hors tâche

        ### Tâche 1 : Préparer

        - [x] **Étape 1 : écrire le test**
          - [ ] sous-case
        - [ ]
        ```
        - [x] dans un bloc de code
        ```
        - [ ] **Étape 2 :** lancer `swift test`
        """)
        #expect(plan.tasks[0].steps == [
            ParsedStep(text: "**Étape 1 : écrire le test**", isChecked: true, line: 7),
            ParsedStep(text: "sous-case", isChecked: false, line: 8),
            ParsedStep(text: "", isChecked: false, line: 9),
            ParsedStep(text: "**Étape 2 :** lancer `swift test`", isChecked: false, line: 13),
        ])
        #expect(plan.tasks[0].total + plan.tasks[0].deferred == plan.tasks[0].steps.count)
    }

    @Test func aDeferredBoxIsKeptAsAStepButLeftOutOfTheCount() {
        let plan = PlanParser.parse("""
        - [-] case isolée reportée

        ### Task 1: Observer

        - [x] **Step 1 :** commiter
        - [-] **Step 2 :** observation à l'usage **À venir**
        - [ ] **Step 3 :** relire
        * [-]
        - [-]reportée sans espace
        """)
        let task = plan.tasks[0]
        #expect(task.checked == 1 && task.total == 2 && task.deferred == 2)
        #expect(task.steps.map(\.isDeferred) == [false, true, false, true])
        #expect(task.steps[1] == ParsedStep(text: "**Step 2 :** observation à l'usage **À venir**", isChecked: false,
                                            line: 6, isDeferred: true))
        #expect(task.steps.count == 4)  // « - [-]reportée sans espace » n'est pas une case
        #expect(plan.looseTotal == 0 && plan.looseChecked == 0 && plan.looseDeferred == 1)
    }

    @Test func aDeferredBoxInCodeIsIgnoredAndATaskOfDeferredBoxesIsNotStarted() {
        let plan = PlanParser.parse("""
        ### Task 1: Reportée
        ```
        - [-] dans un bloc de code
        ```
        - [-] seule case
        """)
        #expect(plan.tasks[0].deferred == 1 && plan.tasks[0].total == 0 && plan.tasks[0].checked == 0)
        #expect(plan.tasks[0].steps.count == 1)
    }

    @Test func ignoresFencedCodeIncludingNestedFences() {
        let plan = PlanParser.parse("""
        # Plan

        ### Task 1: Vraie tâche

        - [ ] étape

        ````markdown
        ### Task 9: Fausse tâche dans un exemple
        ```swift
        let x = 1
        ```
        - [x] fausse case
        ````

        ~~~
        ### Task 8: Autre fausse tâche
        - [x] autre fausse case
        ~~~

        - [ ] deuxième étape
        """)
        #expect(plan.tasks.map(\.number) == [1])
        #expect(plan.tasks[0].total == 2)
        #expect(plan.tasks[0].checked == 0)
    }

    @Test func planWithoutTasks() {
        let plan = PlanParser.parse("# Liste\n\n- [x] un\n- [ ] deux\n- [ ] trois\n")
        #expect(plan.tasks.isEmpty)
        #expect(plan.looseChecked == 1 && plan.looseTotal == 3)
    }

    @Test func readsAnnotatedAndBracedCreateLines() {
        let plan = PlanParser.parse("""
        ### Task 1: Pièces

        **Files:**
        - Create: `apps/macos/X/Messages/{Enumerations,Session,Etat}.swift`
        - Create: `docs/icone.png` (produit par `rsvg-convert`)
        - Modify: `src/a.swift:12-40` (ajoute `extern "C"` et `NULL`, `led`)
        - Test: `a rejeter`

        - [ ] étape
        """)
        let task = plan.tasks[0]
        #expect(task.createdFiles == [
            "apps/macos/X/Messages/Enumerations.swift",
            "apps/macos/X/Messages/Session.swift",
            "apps/macos/X/Messages/Etat.swift",
            "docs/icone.png",
        ])
        #expect(task.touchedFiles == task.createdFiles + ["src/a.swift"])
    }

    @Test func replaceAndQualifiedModifyCountAsTouchedNotCreated() {
        let plan = PlanParser.parse("""
        ### Task 1: Remplacements

        **Files:**
        - Replace: `old/b.swift`
        - Modify (réécrits) : `src/c.swift`
        """)
        #expect(plan.tasks[0].createdFiles.isEmpty)
        #expect(plan.tasks[0].touchedFiles == ["old/b.swift", "src/c.swift"])
    }

    @Test func readsCRLFPlanWithCorrectLineNumbers() {
        let plan = PlanParser.parse("# Plan\r\n\r\n### Task 1: A\r\n\r\n- [x] a\r\n\r\n### Task 2: B\r\n\r\n- [ ] b\r\n")
        #expect(plan.title == "Plan")
        #expect(plan.tasks.map(\.number) == [1, 2])
        #expect(plan.tasks.map(\.line) == [3, 7])
        #expect(plan.tasks[0].checked == 1 && plan.tasks[0].total == 1)
        #expect(plan.tasks[1].checked == 0 && plan.tasks[1].total == 1)
    }

    @Test func backtickLineWithInnerBacktickIsNotAFence() {
        let plan = PlanParser.parse("""
        ### Task 1: A

        - [ ] a
        ```x``` texte
        ### Task 2: B

        - [x] b
        """)
        #expect(plan.tasks.map(\.number) == [1, 2])
        #expect(plan.tasks[1].checked == 1)
    }
}
