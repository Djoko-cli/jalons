import Foundation
import Testing
@testable import JalonsCore
import OrchestreCore

@Suite struct PresentationTests {
    func loaded(spec: String = Samples.spec, plans: [String: String] = [:],
                change: (inout Roadmap) -> Void = { _ in }) throws -> Roadmap {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let url = try folder.writeSpec(spec)
        for (name, text) in plans { try folder.writePlan(text, name: name) }
        guard case .loaded(var roadmap) = RoadmapLoader.load(specURL: url) else { throw CancellationError() }
        change(&roadmap)
        return roadmap
    }

    /// « texte » ou « texte (avertissement) » : un tuple à étiquettes se compare mal dans `#expect`.
    func subtitle(_ index: Int, _ roadmap: Roadmap) -> String {
        let result = Presentation.phaseSubtitle(roadmap.phases[index], in: roadmap)
        return result.isWarning ? "\(result.text) (avertissement)" : result.text
    }

    @Test func subtitlesPutReadErrorsFirst() throws {
        var roadmap = try loaded(plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(subtitle(0, roadmap) == "Terminée")
        #expect(subtitle(1, roadmap) == "60\u{202F}%")
        #expect(subtitle(2, roadmap) == "Plan à écrire")

        roadmap.phases[2].unreadablePlans = [URL(fileURLWithPath: "/tmp/phase-3-noms.md")]
        #expect(subtitle(2, roadmap) == "Plan illisible (avertissement)")

        roadmap.plansDirectoryUnreadable = true
        roadmap.phases[2].unreadablePlans = []
        #expect(subtitle(2, roadmap) == "Plans illisibles (avertissement)")
        #expect(subtitle(0, roadmap) == "Terminée")
    }

    @Test func theMenuLineNeverSaysPlanToWriteForAnUnreadablePlan() throws {
        let roadmap = try loaded { roadmap in
            roadmap.phases[1].unreadablePlans = [URL(fileURLWithPath: "/tmp/phase-2-inventaire.md")]
        }
        #expect(Presentation.currentPhaseDetail(roadmap.phases[1], in: roadmap) == "Plan illisible : phase-2-inventaire.md")
        let noFolder = try loaded { $0.plansDirectoryUnreadable = true }
        #expect(Presentation.currentPhaseDetail(noFolder.phases[1], in: noFolder) == "Dossier des plans illisible")
    }

    @Test func theMenuLineFollowsTheTimelineOrder() throws {
        let done = "### Task 1: Seule tâche\n- [x] Étape\n### Task 2: Sans case\nTexte.\n"
        let signOff = try loaded(plans: ["phase-2-inventaire.md": done])
        #expect(Presentation.currentPhaseDetail(signOff.phases[1], in: signOff)
                == "Toutes les étapes sont cochées : phase à valider")
        let inProgress = try loaded(plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(Presentation.currentPhaseDetail(inProgress.phases[1], in: inProgress)
                == "Prochaine tâche : Tâche 2 : Corriger l'extracteur")
        let noPlan = try loaded()
        #expect(Presentation.currentPhaseDetail(noPlan.phases[1], in: noPlan) == "Plan à écrire")
    }

    @Test func theMenuNamesTheNextStepOfTheNextTask() throws {
        let plan = "### Task 1: Préparer\n- [x] **Étape 1 : écrire le test**\n- [ ] **Étape 2 :** lancer `swift test`\n"
        let roadmap = try loaded(plans: ["phase-2-inventaire.md": plan])
        #expect(Presentation.currentStepDetail(roadmap.phases[1], in: roadmap) == "Étape 2 : lancer swift test")
        let bare = try loaded(plans: ["phase-2-inventaire.md": "### Task 1: Préparer\n- [ ] relire le plan\n"])
        #expect(Presentation.currentStepDetail(bare.phases[1], in: bare) == "Étape suivante : relire le plan")
        let signOff = try loaded(plans: ["phase-2-inventaire.md": "### Task 1: Préparer\n- [x] Étape 1\n"])
        #expect(Presentation.currentStepDetail(signOff.phases[1], in: signOff) == nil)
        let unreadable = try loaded(plans: ["phase-2-inventaire.md": plan]) { roadmap in
            roadmap.phases[1].unreadablePlans = [URL(fileURLWithPath: "/tmp/phase-2-autre.md")]
        }
        #expect(Presentation.currentStepDetail(unreadable.phases[1], in: unreadable) == nil)
        let noPlan = try loaded()
        #expect(Presentation.currentStepDetail(noPlan.phases[1], in: noPlan) == nil)
        let long = try loaded(plans: ["phase-2-inventaire.md": "### Task 1: A\n- [ ] Étape 1 : " + String(repeating: "a", count: 200) + "\n"])
        #expect(Presentation.currentStepDetail(long.phases[1], in: long)?.count == 90)
    }

    @Test func theNextStepBelongsToTheFirstUnfinishedTaskAcrossPlans() throws {
        let plans = ["2026-01-01-phase-2-a.md": "# A\n### Task 1: Faite\n- [x] Étape 1\n### Task 2: Vide\nTexte.\n",
                     "2026-01-02-phase-2-b.md": "# B\n### Task 1: Suivante\n- [x] Étape 1\n- [ ] Étape 2 : relire\n- [ ] Étape 3\n"
                         + "### Task 2: Après\n- [ ] Étape 1\n"]
        let roadmap = try loaded(plans: plans)
        let phase = roadmap.phases[1]
        #expect(Presentation.currentStepDetail(phase, in: roadmap) == "Étape 2 : relire")
        #expect(Presentation.highlightedTask(phase, in: roadmap)?.id == phase.tasks[2].id)
    }

    @Test func nothingIsHighlightedInAFinishedPhaseOrBehindAnUnreadablePlan() throws {
        let plan = "### Task 1: A\n- [ ] Étape 1\n"
        let finished = try loaded(plans: ["phase-1-socle.md": plan])
        #expect(Presentation.highlightedTask(finished.phases[0], in: finished) == nil)
        let unreadable = try loaded(plans: ["phase-2-inventaire.md": plan]) { roadmap in
            roadmap.phases[1].unreadablePlans = [URL(fileURLWithPath: "/tmp/phase-2-autre.md")]
        }
        #expect(Presentation.highlightedTask(unreadable.phases[1], in: unreadable) == nil)
        #expect(Presentation.currentStepDetail(unreadable.phases[1], in: unreadable) == nil)
    }

    @Test func aRepeatedTaskNumberKeepsDistinctKeys() throws {
        let plan = "### Task 1: A\n- [ ] a\n### Task 1: B\n- [ ] b\n### Task 2: C\n- [ ] c\n"
        let roadmap = try loaded(plans: ["phase-2-inventaire.md": plan])
        let keys = roadmap.phases[1].tasks.map(\.key)
        #expect(Set(keys).count == 3)
    }

    @Test func nextStepIsTheFirstUncheckedBox() {
        let tasks = PlanParser.parse("### Task 1: Vide\n### Task 2: En cours\n- [x] a\n- [ ] b\n- [ ] c\n### Task 3: Faite\n- [x] a\n").tasks
        #expect(tasks[0].nextStep == nil)
        #expect(tasks[1].nextStep?.text == "b")
        #expect(tasks[2].nextStep == nil)
    }

    @Test func onlyANumberedStepSkipsThePrefix() throws {
        let text = "### Task 1: A\n- [ ] Étapes de test à relire\n"
        let roadmap = try loaded(plans: ["phase-2-inventaire.md": text])
        #expect(Presentation.currentStepDetail(roadmap.phases[1], in: roadmap) == "Étape suivante : Étapes de test à relire")
        let empty = try loaded(plans: ["phase-2-inventaire.md": "### Task 1: A\n- [ ]\n"])
        #expect(Presentation.currentStepDetail(empty.phases[1], in: empty) == "Étape suivante : Étape sans texte")
        let step = try loaded(plans: ["phase-2-inventaire.md": "### Task 1: A\n- [ ] Step 4: run\n"])
        #expect(Presentation.currentStepDetail(step.phases[1], in: step) == "Step 4: run")
    }

    @Test func stepLabelsDropMarkdownMarks() {
        #expect(Wording.stepLabel(ParsedStep(text: "**Step 3: Run** `swift test`", isChecked: false, line: 1))
                == "Step 3: Run swift test")
        #expect(Wording.stepLabel(ParsedStep(text: "", isChecked: false, line: 1)) == "Étape sans texte")
        #expect(Wording.stepLabel(ParsedStep(text: "relire [la spec](../specs/a.md)", isChecked: false, line: 1))
                == "relire la spec")
    }

    @Test func eachRoadmapHasAShortMenuTitle() throws {
        let roadmap = try loaded(plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(Presentation.roadmapMenuTitle(.loaded(roadmap), specName: "x.md")
                == "Projet d'essai : conception — Phase 2 · 60\u{202F}%")
        var finished = roadmap
        for index in finished.phases.indices { finished.phases[index].isChecked = true }
        #expect(Presentation.roadmapMenuTitle(.loaded(finished), specName: "x.md")
                == "Projet d'essai : conception — terminée")
        let url = URL(fileURLWithPath: "/tmp/x.md")
        #expect(Presentation.roadmapMenuTitle(.failed(.specUnreadable(url)), specName: "x.md") == "x.md — illisible")
        #expect(Presentation.roadmapMenuTitle(.failed(.noPhases(url)), specName: "x.md") == "x.md — aucune phase")
    }

    @Test func onlyDeferredStepsLeftReadsAsAPhaseToSignOffEverywhere() throws {
        let plan = "### Task 1: A\n- [-] a\n- [x] b\n### Task 2: B\n- [-] a\n"
        let roadmap = try loaded(plans: ["phase-2-inventaire.md": plan])
        let phase = roadmap.phases[1]
        #expect(subtitle(1, roadmap) == "À valider")
        #expect(Presentation.currentPhaseDetail(phase, in: roadmap)
                == "Toutes les étapes sont cochées ou reportées : phase à valider")
        #expect(Presentation.currentStepDetail(phase, in: roadmap) == nil)
        #expect(Presentation.highlightedTask(phase, in: roadmap) == nil)
        #expect(Presentation.phasePercent(phase, in: roadmap) == "100\u{202F}%")
        #expect(!roadmap.hasWarnings && Presentation.warnings(roadmap).isEmpty)
        // Un plan fait seulement de cases reportées isolées n'est pas « sans case ».
        let loose = try loaded(plans: ["phase-2-inventaire.md": "# Plan\n- [-] a\n"])
        #expect(!loose.hasWarnings && subtitle(1, loose) == "À valider")
    }

    @Test func aDeferredFirstStepIsSkipped() throws {
        let plan = "### Task 1: A\n- [-] **Step 1 :** filmer\n- [ ] **Step 2 :** relire\n"
        let roadmap = try loaded(plans: ["phase-2-inventaire.md": plan])
        let phase = roadmap.phases[1]
        #expect(Presentation.currentStepDetail(phase, in: roadmap) == "Step 2 : relire")
        #expect(phase.progress == 0 && subtitle(1, roadmap) == "0\u{202F}%")
        #expect(phase.tasks[0].task.status == .todo)
    }

    @Test func theTaskCounterMentionsDeferredBoxes() {
        let tasks = PlanParser.parse("### Task 1: A\n- [x] a\n- [-] b\n### Task 2: B\n- [-] a\n- [-] b\n- [ ] c\n### Task 3: C\n- [x] a\n").tasks
        #expect(Wording.taskCount(tasks[0]) == "1/1 · 1 reportée")
        #expect(Wording.taskCount(tasks[1]) == "0/1 · 2 reportées")
        #expect(Wording.taskCount(tasks[2]) == "1/1")
        let onlyDeferred = PlanParser.parse("### Task 1: A\n- [-] a\n- [-] b\n").tasks[0]
        #expect(Wording.taskCount(onlyDeferred) == "2 reportées")
    }

    @Test func warningsAreWrittenInClear() throws {
        let roadmap = try loaded(spec: Samples.spec + "\n- [ ] Phase 2.1 : sous-étape\n",
                                 plans: ["2026-01-02-plan1-socle.md": "# Plan"]) { roadmap in
            roadmap.plansDirectoryUnreadable = true
            roadmap.phases[1].unreadablePlans = ["a", "b", "c", "d", "e"].map { URL(fileURLWithPath: "/tmp/phase-2-\($0).md") }
        }
        #expect(Presentation.warnings(roadmap) == [
            "Dossier des plans illisible",
            "Plans illisibles : phase-2-a.md, phase-2-b.md, phase-2-c.md et 2 autres",
            "Plan rattaché à aucune phase : 2026-01-02-plan1-socle.md",
            "Case « Phase » ignorée dans la spec, ligne 12",
        ])
    }

    @Test func theIconLabelSaysWhenTheReadIsIncomplete() throws {
        let clean = try loaded(plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(Presentation.accessibilityLabel(.loaded(clean))
                == "Jalons : Phase 2 : Inventaire, 60\u{202F}% ; avancement global 53\u{202F}%")
        let incomplete = try loaded(plans: ["notes.md": "# Notes"])
        #expect(Presentation.accessibilityLabel(.loaded(incomplete)).hasSuffix("lecture incomplète : l'avancement peut être faux"))
        #expect(Presentation.accessibilityLabel(.failed(.noSpecChosen)) == "Jalons : Aucune feuille de route choisie")
    }

    @Test func anUnmeasurablePhaseShowsAQuestionMarkEverywhere() throws {
        let unreadable = try loaded { $0.phases[1].unreadablePlans = [URL(fileURLWithPath: "/tmp/phase-2-x.md")] }
        #expect(Presentation.phasePercent(unreadable.phases[1], in: unreadable) == "?")
        #expect(Presentation.accessibilityLabel(.loaded(unreadable)).contains("Phase 2 : Inventaire, avancement inconnu"))

        let noFolder = try loaded { $0.plansDirectoryUnreadable = true }
        #expect(Presentation.phasePercent(noFolder.phases[0], in: noFolder) == "100\u{202F}%")
        #expect(Presentation.phasePercent(noFolder.phases[1], in: noFolder) == "?")

        let empty = try loaded(plans: ["phase-2-inventaire.md": "# Plan sans case\n\n### Task 1: A écrire\n"])
        #expect(Presentation.phasePercent(empty.phases[1], in: empty) == "?")
        #expect(subtitle(1, empty) == "Plan sans case (avertissement)")
        #expect(Presentation.currentPhaseDetail(empty.phases[1], in: empty)
                == "Plan sans case à cocher : avancement non mesurable")
        #expect(Presentation.warnings(empty) == ["Plan sans case à cocher : phase-2-inventaire.md"])
        #expect(empty.hasWarnings)

        let measured = try loaded(plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(Presentation.phasePercent(measured.phases[1], in: measured) == "60\u{202F}%")
    }

    @Test func aCommentNeverClosedIsAWarning() throws {
        let roadmap = try loaded(spec: Samples.spec + "\n<!-- jamais refermé\n- [ ] Phase 4 : perdue\n")
        #expect(roadmap.phases.map(\.number) == [1, 2, 3])
        #expect(roadmap.hasWarnings)
        #expect(Presentation.warnings(roadmap)
                == ["Commentaire HTML jamais refermé dans la spec, ligne 12 : la suite n'a pas été lue"])
    }
}
