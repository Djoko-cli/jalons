import Foundation
import Testing
@testable import JalonsCore

@Suite struct ProgressTests {
    func loaded(spec: String, plans: [String: String] = [:]) throws -> Roadmap {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let url = try folder.writeSpec(spec)
        for (name, text) in plans { try folder.writePlan(text, name: name) }
        guard case .loaded(let roadmap) = RoadmapLoader.load(specURL: url) else {
            throw CancellationError()
        }
        return roadmap
    }

    @Test func phaseProgressComesFromTheRoadmapBoxThenFromThePlanSteps() throws {
        let roadmap = try loaded(spec: Samples.spec, plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(roadmap.phases[0].progress == 1)
        #expect(roadmap.phases[1].steps.checked == 3)
        #expect(roadmap.phases[1].steps.total == 5)
        #expect(roadmap.phases[1].progress == 0.6)
        #expect(roadmap.phases[2].progress == 0)
        #expect(!roadmap.phases[2].hasPlan)
    }

    @Test func everyPhaseWeighsTheSameInTheOverallProgress() throws {
        let roadmap = try loaded(spec: Samples.spec, plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(abs(roadmap.progress - (1 + 0.6 + 0) / 3) < 1e-9)
        #expect(roadmap.doneCount == 1)
    }

    @Test func theCurrentPhaseIsTheFirstUncheckedOneAndItsNextTaskTheFirstNotDone() throws {
        let roadmap = try loaded(spec: Samples.spec, plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(roadmap.currentPhase?.number == 2)
        #expect(roadmap.status(of: roadmap.phases[0]) == .done)
        #expect(roadmap.status(of: roadmap.phases[1]) == .current)
        #expect(roadmap.status(of: roadmap.phases[2]) == .upcoming)
        #expect(roadmap.phases[1].tasks.map(\.task.status) == [.done, .inProgress, .todo])
        #expect(roadmap.phases[1].nextTask?.task.number == 2)
        #expect(!roadmap.isFinished)
    }

    @Test func aPhaseWhoseStepsAreAllCheckedAwaitsItsRoadmapBox() throws {
        let plan = "### Task 1: Seule tâche\n- [x] Étape 1\n- [x] Étape 2\n"
        let roadmap = try loaded(spec: Samples.spec, plans: ["phase-2-inventaire.md": plan])
        #expect(roadmap.phases[1].awaitsSignOff)
        #expect(roadmap.phases[1].progress == 1)
        #expect(roadmap.currentPhase?.number == 2)
        #expect(!roadmap.phases[2].awaitsSignOff)
    }

    @Test func aRoadmapWithEveryPhaseCheckedIsFinished() throws {
        let roadmap = try loaded(spec: "# Fini\n- [x] Phase 1 : a\n- [x] Phase 2 : b\n")
        #expect(roadmap.isFinished)
        #expect(roadmap.currentPhase == nil)
        #expect(roadmap.progress == 1)
    }

    @Test func percentagesAreRoundedButNeverOverclaimed() {
        #expect(Wording.percent(0) == "0\u{202F}%")
        #expect(Wording.percent(0.29) == "29\u{202F}%")
        #expect(Wording.percent(0.6) == "60\u{202F}%")
        #expect(Wording.percent(0.996) == "99\u{202F}%")
        #expect(Wording.percent(1) == "100\u{202F}%")
        #expect(Wording.percent(0.004) == "1\u{202F}%")
    }

    @Test func labelsAreWrittenInFrench() throws {
        let roadmap = try loaded(spec: Samples.spec, plans: ["phase-2-inventaire.md": Samples.planPhase2])
        #expect(Wording.phaseLabel(roadmap.phases[1]) == "Phase 2 : Inventaire")
        #expect(Wording.taskLabel(roadmap.phases[1].tasks[1].task) == "Tâche 2 : Corriger l'extracteur")
        #expect(Wording.phasesDone(1, of: 7) == "1 phase terminée sur 7")
        #expect(Wording.phasesDone(3, of: 7) == "3 phases terminées sur 7")
    }

    @Test func aCheckedPhaseIsDoneEvenIfItsPlanIsNot() throws {
        let roadmap = try loaded(spec: "# T\n- [x] Phase 1 : a\n- [ ] Phase 2 : b\n",
                                 plans: ["phase-1-a.md": "### Task 1: X\n- [ ] Étape\n"])
        #expect(roadmap.phases[0].progress == 1)
        #expect(roadmap.status(of: roadmap.phases[0]) == .done)
        #expect(roadmap.currentPhase?.number == 2)
    }

    @Test func theFileOrderDecidesWhenNumbersAreOutOfOrder() throws {
        let roadmap = try loaded(spec: "# T\n- [x] Phase 3 : c\n- [ ] Phase 1 : a\n- [ ] Phase 7 : g\n")
        #expect(roadmap.phases.map(\.number) == [3, 1, 7])
        #expect(roadmap.currentPhase?.number == 1)
        #expect(roadmap.status(of: roadmap.phases[2]) == .upcoming)
    }

    @Test func theNextTaskSpansSeveralPlansAndSkipsTasksWithoutBoxes() throws {
        let first = "# Premier plan\n### Task 1: Alpha\n- [x] Étape\n### Task 2: Sans case\nTexte.\n"
        let second = "# Second plan\n### Task 1: Gamma\n- [ ] Étape\n"
        let roadmap = try loaded(spec: Samples.spec, plans: ["phase-2-a.md": first, "phase-2-b.md": second])
        let phase = roadmap.phases[1]
        #expect(phase.tasks.map(\.task.title) == ["Alpha", "Sans case", "Gamma"])
        #expect(phase.nextTask?.task.title == "Gamma")
        #expect(Presentation.taskLabel(phase.nextTask!, in: phase) == "Second plan · Tâche 1 : Gamma")
    }

    @Test func otherLabels() throws {
        let roadmap = try loaded(spec: "# T\n- [ ] Phase 4\n")
        #expect(Wording.phaseLabel(roadmap.phases[0]) == "Phase 4")
        let url = URL(fileURLWithPath: "/tmp/s.md")
        #expect(Wording.failure(.noSpecChosen) == "Aucune feuille de route choisie")
        #expect(Wording.failure(.specUnreadable(url)) == "Feuille de route illisible ou introuvable : s.md")
        #expect(Wording.failure(.noPhases(url)) == "Aucune case « Phase N : … » dans s.md")
        var components = DateComponents()
        components.year = 2026; components.month = 1; components.day = 2; components.hour = 14; components.minute = 32
        let date = Calendar.current.date(from: components)!
        #expect(Wording.updated(date) == "Mis à jour à 14:32")
    }
}
