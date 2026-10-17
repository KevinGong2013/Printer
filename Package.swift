// swift-tools-version:5.7
//  Package.swift
//  Printer

import PackageDescription

let package = Package(
    name: "Printer",
    platforms: [.iOS(.v12), .macOS(.v10_15)],
    products: [
        .library(
            name: "Printer",
            targets: ["Printer"]
        ),
    ],
    targets: [
        .target(
            name: "Printer",
            exclude: ["Info.plist", "Printer.h"]
        ),
        .testTarget(
            name: "PrinterTests",
            dependencies: ["Printer"],
            exclude: ["Info.plist"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
