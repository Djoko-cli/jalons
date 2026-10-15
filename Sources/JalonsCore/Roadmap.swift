import Foundation
import OrchestreCore

/// Une case « Phase N : titre » de la feuille de route d'une spec.
public struct RoadmapEntry: Sendable, Equatable {
    public var number: Int
    public var title: String
    public var isChecked: Bool
    /// Ligne de la case, à partir de 1.
    public var line: Int
}

/// Ce que la spec dit d'elle-même : son titre et les cases de sa feuille de route.
public struct ParsedRoadmap: Sendable, Equatable {
    public var title: String?
    public var entries: [RoadmapEntry]
    /// Lignes des cases « Phase… » non retenues (« Phase 1.1 », numéro en double).
    public var ignoredLines: [Int] = []
}

/// Un plan lu sur le disque.
public struct PlanFile: Sendable, Equatable {
    public var url: URL
    public var title: String?
    public var tasks: [ParsedTask]
    /// Cases hors de toute tâche.
    public var looseChecked: Int
    public var looseTotal: Int
}

/// Une phase : sa case dans la feuille de route et les plans qui la détaillent.
public struct Phase: Sendable, Equatable, Identifiable {
    public var number: Int
    public var title: String
    public var isChecked: Bool
    public var plans: [PlanFile]
    /// Plans présents mais illisibles : signalés, jamais comptés comme vides.
    public var unreadablePlans: [URL]

    public var id: Int { number }
}

/// Une feuille de route lue : la spec, ses phases et l'heure de la lecture.
public struct Roadmap: Sendable, Equatable {
    public var title: String
    public var specURL: URL
    public var phases: [Phase]
    /// Le dossier des plans existe mais n'a pas pu être lu.
    public var plansDirectoryUnreadable: Bool
    /// Plans du dossier qu'aucune phase ne réclame : nom sans « phase-N », ou numéro absent de la feuille de route.
    public var unattachedPlans: [URL] = []
    /// Lignes des cases « Phase… » de la spec qui n'ont pas été retenues.
    public var ignoredBoxLines: [Int] = []
    public var readAt: Date
}

/// Pourquoi il n'y a pas de feuille de route à montrer. Une erreur n'est jamais présentée comme un 0 %.
public enum RoadmapFailure: Sendable, Equatable {
    case noSpecChosen
    case specUnreadable(URL)
    case noPhases(URL)
}

public enum RoadmapState: Sendable, Equatable {
    case loaded(Roadmap)
    case failed(RoadmapFailure)
}
