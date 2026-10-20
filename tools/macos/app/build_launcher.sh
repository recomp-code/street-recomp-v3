#!/bin/sh
# build_launcher.sh <out>: compiles the Mac launcher (NBAStreetV3.swift) with the Xcode command line tools' swiftc.
set -e
cd "$(dirname "$0")"
swiftc -O -target arm64-apple-macos14.0 -o "${1:-NBAStreetV3}" NBAStreetV3.swift
