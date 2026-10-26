#!/bin/zsh
set -eu
cd "$(dirname "$0")"

GYM_APP="${GYM_APP_PATH:-${1:-$HOME/Applications/Gym.app}}"
mkdir -p "$GYM_APP/Contents/MacOS" "$GYM_APP/Contents/Resources"

swiftc Form.swift -o "$GYM_APP/Contents/MacOS/Gym" -framework Cocoa -framework WebKit
if [[ -f Info.plist ]]; then
  cp Info.plist "$GYM_APP/Contents/Info.plist"
fi

rm -rf "$GYM_APP/Contents/Resources/dist"
cp -R dist "$GYM_APP/Contents/Resources/dist"
cp -R dist/. "$GYM_APP/Contents/Resources/"

if [[ -f Gym.icns ]]; then
  cp Gym.icns "$GYM_APP/Contents/Resources/Gym.icns"
fi

codesign --force --sign - --identifier dev.parth.gym "$GYM_APP"
printf 'Built %s\n' "$GYM_APP"
