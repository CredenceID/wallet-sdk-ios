// swift-tools-version: 5.9
//
//  Wallet SDK — Swift Package distribution
//  © 2026 Credence ID LLC. All rights reserved. Internal distribution only.
//
//      .package(url: "https://github.com/CredenceID/wallet-sdk-ios.git", exact: "0.1.0-RC19")
//
//  This repository carries the manifest only. The XCFramework is a release asset produced by
//  the Wallet-SDK Jenkins pipeline; `binaryTarget` fetches it and refuses it unless the
//  SHA-256 matches, so a tampered artifact cannot silently reach an app.
//
//  The repository is public, and has to be: SPM fetches a binary target with a plain HTTPS
//  GET, and GitHub answers 404 to any token on a *private* release asset. Only this manifest
//  and the compiled XCFramework live here; the Kotlin source stays closed in Wallet-SDK.

import PackageDescription

// Bumped together by Scripts/release.sh; the checksum is computed from the built artifact.
let release  = "0.1.0-RC20"
let checksum = "1bbe7a56e8a035702edcc1001d1d8f81df1407a31fc80bedff7c44cc38ed2434"

// Where the binary lives: a release asset on THIS repository, deliberately.
//
// It must not live on Wallet-SDK. That repository holds the Kotlin source and is private,
// which rules it out twice over: SPM cannot authenticate to a private release asset at all,
// and hosting the binary beside the source would mean opening the source to publish a
// binary. Here, the source stays closed and the artifact stays reachable.
let assetURL = "https://github.com/CredenceID/wallet-sdk-ios/releases/download/" +
               "\(release)/WalletSDK-\(release).xcframework.zip"

let package = Package(
    name: "WalletSDK",
    platforms: [
        // Matches the SDK's own deployment target. Kotlin/Native emits an arm64 device slice
        // and an arm64/x86_64 simulator slice; there is no Catalyst or visionOS slice.
        .iOS(.v17)
    ],
    products: [
        // The credential lifecycle: provisioning, storage, presentation, authentication,
        // revocation and configuration, plus logging and runtime security.
        .library(
            name: "WalletSDK",
            targets: ["WalletSDK", "WalletSDKSupport"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "WalletSDK",
            url: assetURL,
            checksum: checksum
        ),

        // Attaches the system libraries the Kotlin/Native runtime and SQLDelight's SQLite
        // cinterop resolve against. A binaryTarget cannot carry linkerSettings, so this
        // source-only target exists to hang them on.
        //
        // These are `.linkedLibrary`, deliberately, not `.unsafeFlags`: SPM rejects unsafe
        // flags in any package consumed as a dependency, so a manifest using them would be
        // unusable by the very apps this package exists to serve. `-ObjC` cannot be expressed
        // safely here at all and must be set by the consuming app target — see README.md.
        .target(
            name: "WalletSDKSupport",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedLibrary("c++"),
                .linkedLibrary("z"),
            ]
        ),
    ]
)
