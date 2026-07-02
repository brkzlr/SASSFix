#!/bin/sh
set -eu

cd "$(dirname "$0")"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/sassfix-hook.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT INT HUP TERM

build_arch() {
    xcrun --sdk iphoneos clang \
        -arch "$1" \
        -miphoneos-version-min=8.0 \
        -dynamiclib \
        -fno-objc-arc \
        -framework Foundation \
        -install_name @executable_path/Frameworks/SASSFix.dylib \
        SASSFixHook.m \
        -o "$2"
}

build_arch arm64 "$tmpdir/SASSFix-arm64.dylib"

if build_arch armv7 "$tmpdir/SASSFix-armv7.dylib" > "$tmpdir/armv7.log" 2>&1; then
    lipo -create -output SASSFix.dylib "$tmpdir/SASSFix-armv7.dylib" "$tmpdir/SASSFix-arm64.dylib"
    echo "Built fat SASSFix.dylib (armv7 + arm64)."
else
    cp "$tmpdir/SASSFix-arm64.dylib" SASSFix.dylib
    echo "Could not build armv7 with this Xcode SDK, generating arm64 only SASSFix.dylib."
fi

codesign -f -s - SASSFix.dylib
lipo -info SASSFix.dylib
