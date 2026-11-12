import Foundation
import PlanParsing

/// Lit une feuille de route complète : la spec, puis les plans de chaque phase (lecteur de plans d'Orchestre).
///
/// Les plans se lisent aussi dans les autres copies de travail du dépôt (`git worktree`), où un plan avance souvent
/// avant de remonter : pour chaque fichier, la version qui a le plus de cases faites ou reportées l'emporte (à égalité,
/// celle de la spec suivie), et un plan qui n'existe que dans une autre copie rejoint sa phase. Ces copies n'ajoutent
/// ni avertissement ni plan non rattaché, et un plan illisible de la spec suivie reste signalé comme tel.
public enum RoadmapLoader {
    public static func load(specURL: URL?, now: Date = Date(), fileManager: FileManager = .default) -> RoadmapState {
        guard let specURL else { return .failed(.noSpecChosen) }
        guard let text = readText(specURL) else { return .failed(.specUnreadable(specURL)) }
        let parsed = RoadmapParser.parse(text)
        guard !parsed.entries.isEmpty else { return .failed(.noPhases(specURL)) }

        var byPhase: [Int: [URL]] = [:]
        var unattached: [URL] = []
        var directoryUnreadable = false
        let sources = PlanLocator.sources(forSpec: specURL, fileManager: fileManager)
        switch PlanLocator.plans(in: sources.directory, fileManager: fileManager) {
        case .found(let found, let others):
            byPhase = found
            unattached = others
        case .missing: break
        case .unreadable: directoryUnreadable = true
        }
        // Un plan « phase-9 » sans phase 9 dans la feuille de route n'est rattaché à rien.
        let known = Set(parsed.entries.map(\.number))
        for (number, urls) in byPhase where !known.contains(number) { unattached += urls }
        unattached.sort { $0.lastPathComponent < $1.lastPathComponent }

        // Les versions des autres copies, par phase connue puis par nom de fichier, dans l'ordre des copies.
        var elsewhere: [Int: [String: [(url: URL, copy: String)]]] = [:]
        for copy in sources.otherCopies {
            guard case .found(let found, _) = PlanLocator.plans(in: copy.directory, fileManager: fileManager) else { continue }
            for (number, urls) in found where known.contains(number) {
                for url in urls { elsewhere[number, default: [:]][url.lastPathComponent, default: []].append((url, copy.name)) }
            }
        }

        let phases = parsed.entries.map { entry -> Phase in
            var plans: [PlanFile] = []
            var unreadable: [URL] = []
            var versions = elsewhere[entry.number] ?? [:]
            for url in byPhase[entry.number] ?? [] {
                let others = versions.removeValue(forKey: url.lastPathComponent) ?? []
                guard let plan = readPlan(url, copy: nil) else {
                    unreadable.append(url)
                    continue
                }
                plans.append(mostAdvanced([plan] + others.compactMap { readPlan($0.url, copy: $0.copy) }))
            }
            for (_, others) in versions {
                let readable = others.compactMap { readPlan($0.url, copy: $0.copy) }
                if !readable.isEmpty { plans.append(mostAdvanced(readable)) }
            }
            plans.sort { $0.url.lastPathComponent < $1.url.lastPathComponent }
            return Phase(number: entry.number, title: entry.title, isChecked: entry.isChecked,
                         plans: plans, unreadablePlans: unreadable)
        }
        return .loaded(Roadmap(title: parsed.title ?? specURL.deletingPathExtension().lastPathComponent,
                               specURL: specURL, phases: phases, plansDirectoryUnreadable: directoryUnreadable,
                               unattachedPlans: unattached, ignoredBoxLines: parsed.ignoredLines,
                               unclosedCommentLine: parsed.unclosedCommentLine, readAt: now))
    }

    static func readPlan(_ url: URL, copy: String?) -> PlanFile? {
        guard let text = readText(url) else { return nil }
        let plan = PlanParser.parse(text)
        return PlanFile(url: url, title: plan.title, tasks: plan.tasks, looseChecked: plan.looseChecked,
                        looseTotal: plan.looseTotal, looseDeferred: plan.looseDeferred, copyName: copy)
    }

    /// La version qui a le plus de cases faites ou reportées ; à égalité, la première (celle de la spec suivie).
    static func mostAdvanced(_ versions: [PlanFile]) -> PlanFile {
        versions.dropFirst().reduce(versions[0]) { $1.settledSteps > $0.settledSteps ? $1 : $0 }
    }

    static func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
