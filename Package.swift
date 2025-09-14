// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TraysarSpatialAwareness",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TraysarSpatialAwareness",
            targets: ["ZEDCameraViewer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", from: "5.3.0")
    ],
    targets: [
        .target(
            name: "GStreamerBridge",
            path: "Sources/GStreamerBridge",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I/opt/homebrew/include/gstreamer-1.0"]),
                .unsafeFlags(["-I/opt/homebrew/include/glib-2.0"]),
                .unsafeFlags(["-I/opt/homebrew/lib/glib-2.0/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L/opt/homebrew/lib"]),
                .linkedLibrary("gstreamer-1.0"),
                .linkedLibrary("gstvideo-1.0"),
                .linkedLibrary("gstapp-1.0"),
                .linkedLibrary("gstbase-1.0"),
                .linkedLibrary("gstgl-1.0"),
                .linkedLibrary("gobject-2.0"),
                .linkedLibrary("glib-2.0"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "ZEDCameraViewer",
            dependencies: ["GStreamerBridge", "SFSafeSymbols"],
            resources: [
                .copy("pacman0.usdc"),
                .copy("remote.png"),
                .copy("router.png"),
                .copy("server.png"),
                .copy("neousys1.png"),
                .copy("brokk.png"),
                .copy("fiber.png"),
                .copy("microphone.png"),
                .copy("traysar-icon.png")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("WebKit"),
                .linkedFramework("SceneKit")
            ]
        ),
    ]
)
