import Foundation
import OrchestreCore

/// Lit une feuille de route complète : la spec, puis les plans de chaque phase (lecteur de plans d'Orchestre).
public enum RoadmapLoader {
    public static func load(specURL: URL?, now: Date = Date(), fileManager: FileManager = .default) -> RoadmapState {
        guard let specURL else { return .failed(.noSpecChosen) }
        guard let text = readText(specURL) else { return .failed(.specUnreadable(specURL)) }
        let parsed = RoadmapParser.parse(text)
        guard !parsed.entries.isEmpty else { return .failed(.noPhases(specURL)) }

        var byPhase: [Int: [URL]] = [:]
        var unattached: [URL] = []
        var directoryUnreadable = false
        switch PlanLocator.plans(in: PlanLocator.plansDirectory(forSpec: specURL), fileManager: fileManager) {
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

        let phases = parsed.entries.map { entry -> Phase in
            var plans: [PlanFile] = []
            var unreadable: [URL] = []
            for url in byPhase[entry.number] ?? [] {
                guard let planText = readText(url) else {
                    unreadable.append(url)
                    continue
                }
                let plan = PlanParser.parse(planText)
                plans.append(PlanFile(url: url, title: plan.title, tasks: plan.tasks,
                                      looseChecked: plan.looseChecked, looseTotal: plan.looseTotal,
                                      looseDeferred: plan.looseDeferred))
            }
            return Phase(number: entry.number, title: entry.title, isChecked: entry.isChecked,
                         plans: plans, unreadablePlans: unreadable)
        }
        return .loaded(Roadmap(title: parsed.title ?? specURL.deletingPathExtension().lastPathComponent,
                               specURL: specURL, phases: phases, plansDirectoryUnreadable: directoryUnreadable,
                               unattachedPlans: unattached, ignoredBoxLines: parsed.ignoredLines,
                               unclosedCommentLine: parsed.unclosedCommentLine, readAt: now))
    }

    static func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
