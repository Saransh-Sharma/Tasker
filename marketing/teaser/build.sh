#!/usr/bin/env bash
# Render every LifeBoard film in every format, mux the generated score, write posters and contact sheets.
# Usage: bash build.sh [film ...]     (default: all four)
set -euo pipefail
cd "$(dirname "$0")"
export CHROME="${CHROME:-$HOME/Library/Caches/ms-playwright/chromium-1223/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing}"
FILMS=("$@"); [ ${#FILMS[@]} -eq 0 ] && FILMS=(bumper-6s teaser-10s advert-30s launch-45s)
mkdir -p out/final
for f in "${FILMS[@]}"; do
  node tools/score.mjs "$f.html" "out/$f.wav"
  for fmt in "9x16 9:16 1080" "16x9 16:9 1920" "1x1 1:1 1080"; do set -- $fmt
    rm -rf "out/$1/$f-frames"
    node render.mjs "$f.html" --ar "$2" --width "$3" --out "out/$1" > "out/$1-$f.log" 2>&1 &
  done; wait
  for d in 9x16 16x9 1x1; do
    tail -2 "out/$d-$f.log"; [ -f "out/$d/$f.mp4" ] || { echo "render failed for $f $d"; cat "out/$d-$f.log"; exit 1; }
    ffmpeg -v error -y -i "out/$d/$f.mp4" -i "out/$f.wav" -c:v copy -af loudnorm=I=-16:TP=-1.5:LRA=11 -c:a aac -b:a 192k -shortest -movflags +faststart "out/final/$f-$d.mp4"
    cp "out/$d/$f.mp4" "out/final/$f-$d-silent.mp4"
    ffmpeg -v error -y -sseof -0.3 -i "out/$d/$f.mp4" -frames:v 1 -update 1 "out/final/$f-$d-poster.png"
    cp "out/$d/$f-contact.jpg" "out/final/$f-$d-contact.jpg"
  done
done
ls -la out/final
