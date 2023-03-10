// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "OKCrashReporter",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_10),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "CrashReporter", targets: ["CrashReporter"]),
    ],
    targets: [
        .target(
            name: "CrashReporter",
            path: "",
            exclude: [
                "Source/dwarf_opstream.hpp",
                "Source/dwarf_stack.hpp",
                "Source/PLCrashAsyncDwarfCFAState.hpp",
                "Source/PLCrashAsyncDwarfCIE.hpp",
                "Source/PLCrashAsyncDwarfEncoding.hpp",
                "Source/PLCrashAsyncDwarfExpression.hpp",
                "Source/PLCrashAsyncDwarfFDE.hpp",
                "Source/PLCrashAsyncDwarfPrimitives.hpp",
                "Source/PLCrashAsyncLinkedList.hpp",
                "Source/PLCrashReport.proto"
            ],
            sources: [
                "Source"
            ],
            cSettings: [
                .define("PLCR_PRIVATE"),
                .define("PLCF_RELEASE_BUILD"),
                .define("PLCRASHREPORTER_PREFIX", to: ""),
                .define("SWIFT_PACKAGE"),
                .headerSearchPath("Source/protobuf-c"),
                .unsafeFlags(["-Wno-shorten-64-to-32"])
            ],
            linkerSettings: [
                .linkedFramework("Foundation")
            ]
        ),
    ]
)
