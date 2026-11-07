// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FireTVRemoteBridge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FireTVRemoteApp", targets: ["FireTVRemoteApp"]),
        .executable(name: "FireTVHelper", targets: ["FireTVHelper"]),
        .executable(name: "FireTVTests", targets: ["FireTVTests"]),
    ],
    targets: [
        .target(name: "FireTVIPC", path: "Sources/FireTVIPC"),
        // libopus is located through pkg-config (Homebrew: `brew install opus`, MacPorts also works).
        .systemLibrary(name: "COpus", path: "Sources/COpus", pkgConfig: "opus", providers: [.brew(["opus"]), .apt(["libopus-dev"])]),
        .target(name: "CMicRing", path: "Sources/CMicRing"),
        .target(name: "FireTVCore", dependencies: ["FireTVIPC", "COpus", "CMicRing"], path: "Sources/FireTVCore"),
        .executableTarget(name: "FireTVRemoteApp", dependencies: ["FireTVCore"], path: "Sources/FireTVRemoteApp"),
        .executableTarget(name: "FireTVHelper", dependencies: ["FireTVIPC"], path: "Sources/FireTVHelper"),
        .executableTarget(name: "FireTVTests", dependencies: ["FireTVCore"], path: "Sources/FireTVTests"),
    ]
)
