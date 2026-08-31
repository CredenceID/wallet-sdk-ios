# Wallet SDK — Swift Package

Swift Package distribution of `WalletSDK.xcframework` for iOS.

> **Internal distribution.** This repository is private. Access requires a CredenceID
> GitHub account and a `~/.netrc` entry — see [Access](#access). Publishing the package
> later removes that step and changes nothing else.

This repository carries the **manifest only**. The binary is a release asset produced by
the `Wallet-SDK` Jenkins pipeline, fetched by SPM and rejected unless its SHA-256 matches
the checksum pinned in `Package.swift`.

| | |
|---|---|
| Current release | `0.1.0-RC19` |
| Deployment target | iOS 17.0 |
| Product | `WalletSDK` |
| Binary source | release assets on this repository |

## Access

SPM downloads binary targets over plain HTTPS and **sends no Xcode credentials**, so a
private release asset needs a `~/.netrc` entry. Without it, resolution fails with a
checksum or "invalid archive" error that points nowhere near the real cause.

1. Create a personal access token with `repo` scope at
   <https://github.com/settings/tokens>.

2. Add it to `~/.netrc`:

   ```
   machine github.com
     login <your-github-username>
     password <your-token>
   ```

3. Lock the file down — it holds a credential:

   ```sh
   chmod 600 ~/.netrc
   ```

4. Confirm it works before touching Xcode:

   ```sh
   Scripts/verify-access.sh
   ```

Git access to this repository itself uses your normal Xcode account or SSH key; `.netrc`
is only for the binary download.

## Using it

```swift
dependencies: [
    .package(
        url: "https://github.com/CredenceID/wallet-sdk-ios.git",
        exact: "0.1.0-RC19"
    )
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "WalletSDK", package: "wallet-sdk-ios")
    ])
]
```

**Pin with `exact:`.** Every release so far is a semver pre-release, and SPM's range rules
(*Up to Next Major*, *Up to Next Minor*) never resolve to a pre-release — a range silently
finds no version at all. The version matches the Android artifact
(`com.credenceid:wallet-sdk:0.1.0-RC19`) because both come from the same git tag; pin both
platforms to the same version.

**One required app-target setting.** The package attaches `libsqlite3`, `libc++` and
`libz` for you. `-ObjC` it cannot — SPM rejects unsafe linker flags in any package consumed
as a dependency — so add it to the app target that links the SDK:

```
Other Linker Flags:  -ObjC
```

Without it, Objective-C categories inside the static framework are not loaded, and you get
selector-not-found failures at runtime rather than errors at link time.

## Cutting a release

**Jenkins does this.** The `Wallet-SDK` pipeline publishes the XCFramework here on a tagged
master build or a `release`-branch build, then checksums the artifact, commits `Package.swift`
and pushes the tag. The version comes from `VERSION_NAME` in `Wallet-SDK/gradle.properties`,
so it matches the Android artifact of the same build. Bump `VERSION_NAME` per RC: a second
build at a version already published skips rather than overwriting a consumed binary.

The steps below are the same thing by hand, for a release the pipeline could not cut.
Tags here must match `Wallet-SDK` release tags exactly — the tag is what SPM resolves.

```sh
# after the pipeline has published the release asset
Scripts/release.sh 0.1.0-RC20

# or against a locally built zip, before it is published
Scripts/release.sh 0.1.0-RC20 /path/to/WalletSDK-0.1.0-RC20.xcframework.zip
```

The script downloads the published asset, computes the SPM checksum, rewrites
`Package.swift`, re-validates the manifest, and prints the commit/tag/push commands. It
pushes nothing.

It checksums **the published bytes**, not a local rebuild — Kotlin/Native output is not
bit-identical between builds, and a mismatched checksum fails resolution for every
consumer at once.

## Going public

**One change:** flip this repository's visibility. The binary is a release asset here, so it
becomes public with it — `assetURL` does not move, and no pipeline change is needed. The
`~/.netrc` step in [Access](#access) then becomes unnecessary; delete that section.

Nothing about the package structure, product name, or consumer snippet changes.

## Layout

```
Package.swift                       manifest — version, checksum, asset URL
Scripts/release.sh                  cut a release
Scripts/verify-access.sh            diagnose private-binary access
Sources/WalletSDKSupport/Empty.swift  carries the linkerSettings a binaryTarget cannot
```

---

© 2026 Credence ID LLC. All rights reserved. Internal use only; not for redistribution.
