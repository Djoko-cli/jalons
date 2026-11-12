import Foundation
import Testing
@testable import JalonsCore

@Suite(.serialized) struct WorkingCopiesTests {
    let specPath = "docs/superpowers/specs/2026-01-01-projet-design.md"

    @Test func listsEveryCopyOfTheRepositoryWithItsBranch() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let feature = try git.addCopy("copie-fonction", branch: "fonction")
        let detached = try git.addCopy("copie-detachee", branch: nil)
        let spec = try git.write("# Projet\n", to: specPath, in: git.main)

        let copies = try #require(WorkingCopies.around(spec))
        #expect(copies.current == WorkingCopy(root: git.main, name: "main"))
        #expect(copies.others.map(\.name).sorted() == ["copie-detachee", "fonction"])
        #expect(Set(copies.others.map(\.root)) == [feature, detached])
        #expect(copies.registry.path == git.main.appendingPathComponent(".git/worktrees").path)
    }

    @Test func fromACopyTheMainCheckoutIsAnotherCopy() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let feature = try git.addCopy("copie-fonction", branch: "fonction")
        let spec = try git.write("# Projet\n", to: specPath, in: feature)

        let copies = try #require(WorkingCopies.around(spec))
        #expect(copies.current == WorkingCopy(root: feature, name: "fonction"))
        #expect(copies.others == [WorkingCopy(root: git.main, name: "main")])
    }

    @Test func aCopyWhoseFolderIsGoneIsLeftOut() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let gone = try git.addCopy("copie-effacee", branch: "effacee")
        try git.addCopy("copie-fonction", branch: "fonction")
        try FileManager.default.removeItem(at: gone)
        let spec = try git.write("# Projet\n", to: specPath, in: git.main)

        #expect(WorkingCopies.around(spec)?.others.map(\.name) == ["fonction"])
    }

    @Test func copiesWrittenWithRelativePathsAreFound() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let relative = try git.addCopy("copie-relative", branch: "relative", relative: true)
        let gitdir = try String(contentsOf: git.main.appendingPathComponent(".git/worktrees/copie-relative/gitdir"),
                                encoding: .utf8)
        #expect(!gitdir.hasPrefix("/"))
        let fromMain = try git.write("# Projet\n", to: specPath, in: git.main)
        #expect(WorkingCopies.around(fromMain)?.others == [WorkingCopy(root: relative, name: "relative")])
        let fromCopy = try git.write("# Projet\n", to: specPath, in: relative)
        #expect(WorkingCopies.around(fromCopy)?.current == WorkingCopy(root: relative, name: "relative"))
        #expect(WorkingCopies.around(fromCopy)?.others == [WorkingCopy(root: git.main, name: "main")])
    }

    @Test func aBareRepositoryInsideDotGitIsNotACopy() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let project = git.root.appendingPathComponent("projet", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try git.git(["clone", "-q", "--bare", git.main.path, project.appendingPathComponent(".git").path], in: git.root)
        let copy = project.appendingPathComponent("copie-main", isDirectory: true)
        try git.git(["worktree", "add", "-q", "-b", "travail", copy.path], in: project.appendingPathComponent(".git"))
        let spec = try git.write("# Projet\n", to: specPath, in: copy)

        let copies = try #require(WorkingCopies.around(spec))
        #expect(copies.current == WorkingCopy(root: copy, name: "travail"))
        #expect(copies.others.isEmpty)
    }

    @Test func aSubmoduleDoesNotBorrowTheCopiesOfItsParent() throws {
        let git = try GitCopies()
        defer { git.remove() }
        try git.addCopy("copie-fonction", branch: "fonction")
        let inner = try GitCopies(root: git.root.appendingPathComponent("depot-interne", isDirectory: true))
        try git.git(["submodule", "add", "-q", inner.main.path, "sous-module"], in: git.main)
        let spec = try git.write("# Projet\n", to: "sous-module/" + specPath, in: git.main)

        let copies = try #require(WorkingCopies.around(spec))
        #expect(copies.current.root.path == git.main.appendingPathComponent("sous-module").path)
        #expect(copies.others.isEmpty)
    }

    @Test func outsideARepositoryThereAreNoCopies() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let spec = try folder.writeSpec("# Projet\n")
        // Le dossier temporaire n'est pas dans un dépôt git.
        #expect(WorkingCopies.around(spec) == nil)
    }
}

@Suite(.serialized) struct OtherCopiesPlansTests {
    let spec = "docs/superpowers/specs/2026-01-01-projet-design.md"
    let plans = "docs/superpowers/plans/"
    let roadmap = "# Projet\n\n- [x] Phase 1 : socle\n- [ ] Phase 2 : interface\n- [ ] Phase 3 : publication\n"

    func plan(_ checked: Int, of total: Int) -> String {
        "### Task 1: A\n" + (0..<total).map { $0 < checked ? "- [x] e\($0)\n" : "- [ ] e\($0)\n" }.joined()
    }

    func load(_ git: GitCopies, from copy: URL? = nil) throws -> Roadmap {
        let url = (copy ?? git.main).appendingPathComponent(spec)
        guard case .loaded(let roadmap) = RoadmapLoader.load(specURL: url) else { throw CancellationError() }
        return roadmap
    }

    @Test func theMostAdvancedVersionOfAPlanWins() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let ahead = try git.addCopy("copie-avance", branch: "avance")
        let behind = try git.addCopy("copie-retard", branch: "retard")
        try git.write(roadmap, to: spec, in: git.main)
        try git.write(plan(1, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: git.main)
        let advanced = try git.write(plan(3, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: ahead)
        try git.write(plan(0, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: behind)

        let phase = try load(git).phases[1]
        #expect(phase.plans.count == 1)
        #expect(phase.plans[0].url.path == advanced.path)
        #expect(phase.plans[0].copyName == "avance")
        #expect(phase.steps.checked == 3)
    }

    @Test func onATieBetweenOtherCopiesTheFirstByNameWins() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let first = try git.addCopy("copie-a", branch: "a")
        let second = try git.addCopy("copie-b", branch: "b")
        try git.write(roadmap, to: spec, in: git.main)
        try git.write(plan(1, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: git.main)
        let winner = try git.write(plan(3, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: first)
        try git.write(plan(3, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: second)

        let phase = try load(git).phases[1]
        #expect(phase.plans.map(\.url.path) == [winner.path])
    }

    @Test func aTaskKeepsItsKeyWhenTheWinningVersionMovesToAnotherCopy() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let other = try git.addCopy("copie-fonction", branch: "fonction")
        try git.write(roadmap, to: spec, in: git.main)
        try git.write(plan(2, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: git.main)
        let before = try load(git).phases[1].tasks.map(\.key)
        try git.write(plan(3, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: other)
        let after = try load(git).phases[1]
        #expect(after.plans[0].copyName == "fonction")
        #expect(after.tasks.map(\.key) == before)
    }

    @Test func onATieTheFollowedCopyWins() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let other = try git.addCopy("copie-egale", branch: "egale")
        try git.write(roadmap, to: spec, in: git.main)
        let mine = try git.write(plan(2, of: 4), to: plans + "2026-01-02-phase-2-interface.md", in: git.main)
        try git.write(plan(2, of: 5), to: plans + "2026-01-02-phase-2-interface.md", in: other)

        let phase = try load(git).phases[1]
        #expect(phase.plans.map(\.url.path) == [mine.path])
        #expect(phase.plans[0].copyName == nil)
    }

    @Test func aPlanFoundOnlyInAnotherCopyJoinsItsPhaseInNameOrder() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let other = try git.addCopy("copie-fonction", branch: "fonction")
        try git.write(roadmap, to: spec, in: git.main)
        try git.write(plan(4, of: 4), to: plans + "2026-01-02-phase-2a-ecrans.md", in: git.main)
        try git.write(plan(4, of: 4), to: plans + "2026-01-04-phase-2c-fin.md", in: git.main)
        try git.write(plan(1, of: 5), to: plans + "2026-01-03-phase-2b-coeur.md", in: other)

        let roadmap = try load(git)
        let phase = roadmap.phases[1]
        #expect(phase.plans.map { $0.url.lastPathComponent }
                == ["2026-01-02-phase-2a-ecrans.md", "2026-01-03-phase-2b-coeur.md", "2026-01-04-phase-2c-fin.md"])
        #expect(phase.plans.map(\.copyName) == [nil, "fonction", nil])
        #expect(!phase.awaitsSignOff && phase.steps.checked == 9 && phase.steps.total == 13)
        #expect(phase.tasks.map(\.copyName) == [nil, "fonction", nil])
    }

    @Test func theMenuSaysWhenTheNextTaskIsInAnotherCopy() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let other = try git.addCopy("copie-fonction", branch: "fonction")
        try git.write(roadmap, to: spec, in: git.main)
        try git.write("# Plan 2b\n" + plan(1, of: 3), to: plans + "2026-01-03-phase-2b-coeur.md", in: other)

        let roadmap = try load(git)
        #expect(Presentation.currentPhaseDetail(roadmap.phases[1], in: roadmap)
                == "Prochaine tâche : Tâche 1 : A (copie de travail)")
    }

    @Test func otherCopiesAddNoWarningAndNoUnknownPhase() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let other = try git.addCopy("copie-fonction", branch: "fonction")
        let empty = try git.addCopy("copie-sans-plans", branch: "sans-plans")
        try git.write(roadmap, to: spec, in: git.main)
        try git.write(plan(1, of: 2), to: plans + "2026-01-02-phase-2-interface.md", in: git.main)
        try git.write(plan(1, of: 2), to: plans + "notes-diverses.md", in: other)
        try git.write(plan(1, of: 2), to: plans + "2026-01-09-phase-9-ailleurs.md", in: other)
        let locked = try git.write(plan(2, of: 2), to: plans + "2026-01-02-phase-2-interface.md", in: other)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }
        _ = empty

        let roadmap = try load(git)
        #expect(!roadmap.hasWarnings)
        #expect(roadmap.phases[1].plans.map(\.copyName) == [nil])
        #expect(roadmap.phases.allSatisfy { $0.unreadablePlans.isEmpty })
    }

    @Test func anUnreadablePlanOfTheFollowedCopyIsNotHiddenByAnotherCopy() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let other = try git.addCopy("copie-fonction", branch: "fonction")
        try git.write(roadmap, to: spec, in: git.main)
        let locked = try git.write(plan(1, of: 2), to: plans + "2026-01-02-phase-2-interface.md", in: git.main)
        try git.write(plan(2, of: 2), to: plans + "2026-01-02-phase-2-interface.md", in: other)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }

        let phase = try load(git).phases[1]
        #expect(phase.unreadablePlans.map(\.lastPathComponent) == ["2026-01-02-phase-2-interface.md"])
        #expect(phase.plans.isEmpty)
    }

    @Test func theSourcesNameEveryOtherPlansFolder() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let other = try git.addCopy("copie-fonction", branch: "fonction")
        let specURL = try git.write(roadmap, to: spec, in: git.main)

        let sources = PlanLocator.sources(forSpec: specURL)
        #expect(sources.directory.standardizedFileURL.path
                == git.main.appendingPathComponent("docs/superpowers/plans").path)
        #expect(sources.otherCopies.map(\.name) == ["fonction"])
        #expect(sources.otherCopies.map { $0.directory.standardizedFileURL.path }
                == [other.appendingPathComponent("docs/superpowers/plans").path])
        #expect(sources.registry?.lastPathComponent == "worktrees")
    }

    @Test func theWatchScopeSeesPlansOfEveryCopyAndCopiesComingAndGoing() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let other = try git.addCopy("copie-fonction", branch: "fonction")
        let specURL = try git.write(roadmap, to: spec, in: git.main)
        try git.write("x", to: plans + "a.md", in: other)

        let scope = WatchScope(specURL: specURL, sources: PlanLocator.sources(forSpec: specURL))
        let registry = git.main.appendingPathComponent(".git/worktrees").path
        #expect(scope.roots == [git.main.appendingPathComponent("docs/superpowers").path, other.path,
                                git.main.appendingPathComponent(".git").path])
        #expect(scope.accepts(registry))
        #expect(scope.accepts(registry + "/copie-fonction/gitdir"))
        #expect(scope.accepts(registry + "/copie-fonction/HEAD"))
        #expect(!scope.accepts(git.main.appendingPathComponent(".git/index").path))
        #expect(scope.accepts(git.main.appendingPathComponent(".git/HEAD").path))
        #expect(scope.accepts(git.main.appendingPathComponent(spec).path))
        #expect(scope.accepts(git.main.appendingPathComponent(plans + "2026-01-02-phase-2-x.md").path))
        #expect(scope.accepts(other.appendingPathComponent(plans + "2026-01-02-phase-2-x.md").path))
        #expect(scope.accepts(registry + "/copie-neuve"))
        #expect(!scope.accepts(registry + "/copie-fonction/index"))
        #expect(!scope.accepts(other.appendingPathComponent("docs/superpowers/specs/b.md").path))
        #expect(!scope.accepts(git.main.appendingPathComponent("Sources/a.swift").path))
    }

    @Test func theFirstCopyOfARepositoryIsSeenComing() throws {
        let git = try GitCopies()
        defer { git.remove() }
        let specURL = try git.write(roadmap, to: spec, in: git.main)
        let registry = git.main.appendingPathComponent(".git/worktrees")
        #expect(!FileManager.default.fileExists(atPath: registry.path))

        let scope = WatchScope(specURL: specURL, sources: PlanLocator.sources(forSpec: specURL))
        #expect(scope.roots.contains(git.main.appendingPathComponent(".git").path))
        #expect(scope.accepts(registry.path))
        #expect(scope.accepts(registry.path + "/copie-neuve"))
    }

    @Test func outsideARepositoryTheScopeIsTheSpecAndItsPlans() throws {
        let folder = try FixtureFolder()
        defer { folder.remove() }
        let specURL = try folder.writeSpec("# Projet\n")
        let scope = WatchScope(specURL: specURL, sources: PlanLocator.sources(forSpec: specURL))
        #expect(scope.roots == [canonicalPath(folder.root.appendingPathComponent("docs/superpowers"))])
        #expect(scope.accepts(canonicalPath(folder.plansDirectory) + "/p.md"))
    }
}
