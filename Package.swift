// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jalons",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Jalons", targets: ["Jalons"]),
    ],
    targets: [
        // Le lecteur de plans, copié d'Orchestre (voir l'en-tête de ses fichiers).
        .target(name: "PlanParsing"),
        .target(name: "JalonsCore", dependencies: ["PlanParsing"]),
        .executableTarget(name: "Jalons", dependencies: ["JalonsCore"]),
        .testTarget(name: "PlanParsingTests", dependencies: ["PlanParsing"]),
        .testTarget(name: "JalonsCoreTests", dependencies: ["JalonsCore", "PlanParsing"]),
        .testTarget(name: "JalonsAppTests", dependencies: ["Jalons"]),
    ]
)
