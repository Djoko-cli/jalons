import Foundation
import Testing
@testable import JalonsCore

@Suite struct PlanLocatorTests {
    @Test func readsThePhaseNumberFromTheFileName() {
        #expect(PlanLocator.phaseNumber(inFileName: "2026-01-02-phase-1-socle.md") == 1)
        #expect(PlanLocator.phaseNumber(inFileName: "phase_03_noms.md") == 3)
        #expect(PlanLocator.phaseNumber(inFileName: "Phase10.md") == 10)
        #expect(PlanLocator.phaseNumber(inFileName: "plan phase 2.md") == 2)
        #expect(PlanLocator.phaseNumber(inFileName: "emphase-2.md") == nil)
        #expect(PlanLocator.phaseNumber(inFileName: "notes.md") == nil)
        #expect(PlanLocator.phaseNumber(inFileName: "phase-2.txt") == nil)
    }

    @Test func thePlansFolderIsTheSiblingOfTheSpecsFolder() {
        let spec = URL(fileURLWithPath: "/tmp/projet/docs/superpowers/specs/s.md")
        #expect(PlanLocator.plansDirectory(forSpec: spec).path == "/tmp/projet/docs/superpowers/plans")
    }

    @Test func groupsThePlansByPhaseInNameOrder() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        try folder.writePlan("# b", name: "2026-01-03-phase-2-suite.md")
        try folder.writePlan("# a", name: "2026-01-02-phase-2-debut.md")
        try folder.writePlan("# c", name: "2026-01-02-phase-1-socle.md")
        try folder.writePlan("# d", name: "notes.md")
        try folder.writePlan("# e", name: ".phase-3-cache.md")
        guard case .found(let byPhase, let unattached) = PlanLocator.plans(in: folder.plansDirectory) else {
            Issue.record("dossier des plans non lu")
            return
        }
        #expect(Set(byPhase.keys) == [1, 2])
        #expect(byPhase[2]?.map(\.lastPathComponent) == ["2026-01-02-phase-2-debut.md", "2026-01-03-phase-2-suite.md"])
        #expect(unattached.map(\.lastPathComponent) == ["notes.md"])
    }

    @Test func aFolderNamedLikeAPlanIsNotAPlan() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        try folder.writePlan("# a", name: "phase-1-socle.md")
        try FileManager.default.createDirectory(at: folder.plansDirectory.appendingPathComponent("phase-2.md"),
                                                withIntermediateDirectories: true)
        guard case .found(let byPhase, let unattached) = PlanLocator.plans(in: folder.plansDirectory) else {
            Issue.record("dossier des plans non lu")
            return
        }
        #expect(Set(byPhase.keys) == [1])
        #expect(unattached.isEmpty)
    }

    @Test(.enabled(if: getuid() != 0, "les droits ne s'appliquent pas à root"))
    func anUnreadablePlansFolderIsReported() throws {
        let folder = try FixtureFolder()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.plansDirectory.path)
            folder.remove()
        }
        try folder.writePlan("# a", name: "phase-1-socle.md")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.plansDirectory.path)
        #expect(PlanLocator.plans(in: folder.plansDirectory) == .unreadable)
    }

    @Test func aMissingPlansFolderIsNotAnError() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        #expect(PlanLocator.plans(in: folder.plansDirectory) == .missing)
    }
}
