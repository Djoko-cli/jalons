import Foundation
import Testing
@testable import JalonsCore

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
