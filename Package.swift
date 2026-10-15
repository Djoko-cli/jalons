// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jalons",
    platforms: [.macOS(.v15)],
    dependencies: [
        // Le lecteur de plans d'Orchestre, depuis le dépôt voisin.
        .package(path: "../orchestre"),
    ],
    targets: [
        .target(name: "JalonsCore", dependencies: [.product(name: "OrchestreCore", package: "orchestre")]),
        .testTarget(name: "JalonsCoreTests",
                    dependencies: ["JalonsCore", .product(name: "OrchestreCore", package: "orchestre")]),
    ]
)
