#!/usr/bin/env bash
# Download Apple's macOS 27 Golden Gate wallpapers (Dark, and the Golden Gate Bridge
# photo) into your Omarchy backgrounds for this theme, and switch to the Dark one.
# They are Apple's artwork, so they are fetched to your machine rather than shipped here.
set -euo pipefail

base="https://media.512pixels.net/downloads"
dest="$HOME/.config/omarchy/backgrounds/golden-gate"
mkdir -p -- "$dest"

fetch() {
  local url="$1" out="$dest/$2"
  if [[ -s $out ]]; then
    echo "Already have $2"
  else
    echo "Downloading $2"
    curl -fL --progress-bar -o "$out.part" -- "$url"
    mv -- "$out.part" "$out"
  fi
}

# User backgrounds sort ahead of the theme's own, so the Dark wallpaper becomes the default.
fetch "$base/macos-wallpapers-thumbs/27-Golden-Gate-thumb-dark.png" "1-golden-gate-dark.png"
fetch "$base/macos-wallpapers-6k/27-Golden-Gate-Bridge.jpg" "2-golden-gate-bridge.jpg"

if [[ $(omarchy theme current 2>/dev/null) == "Golden Gate" ]]; then
  omarchy theme bg set "$dest/1-golden-gate-dark.png"
fi
echo "Done. Cycle wallpapers with: omarchy theme bg next"
