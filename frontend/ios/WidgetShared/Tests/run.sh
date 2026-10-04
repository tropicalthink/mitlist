#!/bin/sh
# Compiles the Foundation-only widget core with a test main and runs it
# against the shared fixtures in contracts/widgets (plan 047).
#   frontend/ios/WidgetShared/Tests/run.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
core="$here/../Core"
fixtures="$here/../../../../contracts/widgets"
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
xcrun swiftc -swift-version 5 -O -o "$out/widget-core-tests" "$core"/*.swift "$here/main.swift"
"$out/widget-core-tests" "$fixtures"
