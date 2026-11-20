#!/usr/bin/env bash
# Runs the pure-Swift engine unit tests (Tests/) without Xcode, using SwiftPM.
# Works on macOS or Linux (e.g. `docker run --rm -v "$PWD":/src -w /src swift:6.0-noble Scripts/test_engines_linux.sh`).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="${TMPDIR:-/tmp}/quizlock-engine-pkg"
rm -rf "$PKG"
mkdir -p "$PKG/Sources/Engine" "$PKG/Tests/EngineTests"
for f in "$ROOT"/Shared/Engine/*.swift; do ln -s "$f" "$PKG/Sources/Engine/"; done
for f in "$ROOT"/Tests/*.swift; do
  # Tests compile the engine sources directly in Xcode; under SwiftPM import the module instead.
  { echo "@testable import Engine"; cat "$f"; } > "$PKG/Tests/EngineTests/$(basename "$f")"
done
# Point TestResources at the repo's Resources folder.
sed -i.bak "s|let here = URL(fileURLWithPath: \"\\\\(file)\")|let here = URL(fileURLWithPath: \"$ROOT/Tests/x.swift\")|" "$PKG/Tests/EngineTests/TestResources.swift"
rm -f "$PKG/Tests/EngineTests/"*.bak
cat > "$PKG/Package.swift" <<'SWIFT'
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "Engine",
    targets: [
        .target(name: "Engine", swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]),
        .testTarget(name: "EngineTests", dependencies: ["Engine"]),
    ]
)
SWIFT
cd "$PKG"
swift build -c release --build-tests -Xswiftc -enable-testing
swift test -c release -Xswiftc -enable-testing --skip-build "$@"
