import Foundation
import Testing
@testable import JalonsCore

@Suite struct RoadmapLoaderTests {
    @Test func noSpecChosen() {
        #expect(RoadmapLoader.load(specURL: nil) == .failed(.noSpecChosen))
    }

    @Test func aMissingSpecIsReportedAsUnreadable() {
        let url = URL(fileURLWithPath: "/tmp/jalons-introuvable-\(UUID().uuidString).md")
        #expect(RoadmapLoader.load(specURL: url) == .failed(.specUnreadable(url)))
    }

    @Test func aSpecWithoutPhaseBoxesIsReported() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let spec = try folder.writeSpec("# Titre\n\n- [ ] Une tâche\n")
        #expect(RoadmapLoader.load(specURL: spec) == .failed(.noPhases(spec)))
    }

    @Test func readsThePhasesAndTheirPlans() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let spec = try folder.writeSpec(Samples.spec)
        try folder.writePlan(Samples.planPhase2, name: "2026-01-02-phase-2-inventaire.md")
        guard case .loaded(let roadmap) = RoadmapLoader.load(specURL: spec) else {
            Issue.record("feuille de route non lue")
            return
        }
        #expect(roadmap.title == "Projet d'essai : conception")
        #expect(roadmap.phases.map(\.number) == [1, 2, 3])
        #expect(roadmap.phases[0].plans.isEmpty)
        #expect(roadmap.phases[1].plans.count == 1)
        #expect(roadmap.phases[1].tasks.map(\.task.number) == [1, 2, 3])
        #expect(!roadmap.hasReadProblems)
    }

    @Test(.enabled(if: getuid() != 0, "les droits ne s'appliquent pas à root"))
    func anUnreadablePlanIsReportedAndNotCounted() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let spec = try folder.writeSpec(Samples.spec)
        let plan = try folder.writePlan(Samples.planPhase2, name: "phase-2-inventaire.md")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: plan.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: plan.path) }
        guard case .loaded(let roadmap) = RoadmapLoader.load(specURL: spec) else {
            Issue.record("feuille de route non lue")
            return
        }
        #expect(roadmap.phases[1].unreadablePlans.map(\.lastPathComponent) == ["phase-2-inventaire.md"])
        #expect(roadmap.phases[1].plans.isEmpty)
        #expect(roadmap.hasReadProblems)
    }

    @Test func aPlanThatIsNotUTF8IsUnreadable() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let spec = try folder.writeSpec(Samples.spec)
        try FileManager.default.createDirectory(at: folder.plansDirectory, withIntermediateDirectories: true)
        try Data([0xFF, 0xFE, 0xFD, 0x00, 0xC3]).write(to: folder.plansDirectory.appendingPathComponent("phase-2-x.md"))
        guard case .loaded(let roadmap) = RoadmapLoader.load(specURL: spec) else {
            Issue.record("feuille de route non lue")
            return
        }
        #expect(roadmap.phases[1].unreadablePlans.count == 1)
        #expect(roadmap.hasReadProblems)
    }

    @Test(.enabled(if: getuid() != 0, "les droits ne s'appliquent pas à root"))
    func anUnreadablePlansFolderMakesTheReadIncomplete() throws {
        let folder = try FixtureFolder()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.plansDirectory.path)
            folder.remove()
        }
        let spec = try folder.writeSpec(Samples.spec)
        try folder.writePlan(Samples.planPhase2, name: "phase-2-inventaire.md")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.plansDirectory.path)
        guard case .loaded(let roadmap) = RoadmapLoader.load(specURL: spec) else {
            Issue.record("feuille de route non lue")
            return
        }
        #expect(roadmap.plansDirectoryUnreadable)
        #expect(roadmap.hasReadProblems)
        #expect(roadmap.hasWarnings)
    }

    @Test func anEmptySpecHasNoPhasesAndASpecWithoutTitleUsesItsFileName() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let empty = try folder.writeSpec("", name: "vide.md")
        #expect(RoadmapLoader.load(specURL: empty) == .failed(.noPhases(empty)))
        let untitled = try folder.writeSpec("- [ ] Phase 1 : a\n", name: "2026-01-01-sans-titre.md")
        guard case .loaded(let roadmap) = RoadmapLoader.load(specURL: untitled) else {
            Issue.record("feuille de route non lue")
            return
        }
        #expect(roadmap.title == "2026-01-01-sans-titre")
    }

    @Test func plansThatNoPhaseClaimsAreListed() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let spec = try folder.writeSpec(Samples.spec)
        try folder.writePlan("# Plan", name: "2026-01-02-plan1-socle.md")
        try folder.writePlan("# Plan", name: "2026-01-03-phase-9-ailleurs.md")
        try folder.writePlan(Samples.planPhase2, name: "2026-01-04-phase-2-inventaire.md")
        guard case .loaded(let roadmap) = RoadmapLoader.load(specURL: spec) else {
            Issue.record("feuille de route non lue")
            return
        }
        #expect(roadmap.unattachedPlans.map(\.lastPathComponent)
                == ["2026-01-02-plan1-socle.md", "2026-01-03-phase-9-ailleurs.md"])
        #expect(roadmap.hasWarnings)
        #expect(!roadmap.hasReadProblems)
        #expect(roadmap.phases[1].hasPlan)
    }
}
