#!/bin/zsh
# Builds Sprig.app into build/. Pass --install to copy it to /Applications and open it.
set -e
cd "$(dirname "$0")"
[ -d /Applications/Xcode.app ] && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
A=build/Sprig.app; rm -rf "$A"; mkdir -p "$A/Contents/MacOS" "$A/Contents/Resources"
SDK=$(xcrun --sdk macosx --show-sdk-path)
for arch in arm64 x86_64; do xcrun swiftc -O -swift-version 5 -parse-as-library -sdk "$SDK" -target $arch-apple-macos13.0 Sources/*.swift -o build/Sprig-$arch; done
lipo -create build/Sprig-arm64 build/Sprig-x86_64 -output "$A/Contents/MacOS/Sprig"; rm build/Sprig-*
cp Info.plist "$A/Contents/"; cp Resources/* "$A/Contents/Resources/"
codesign --force -s - "$A"
"$A/Contents/MacOS/Sprig" --selftest
if [ "$1" = "--install" ]; then pkill -x Sprig || true; rm -rf /Applications/Sprig.app; cp -R "$A" /Applications/; open /Applications/Sprig.app; fi
