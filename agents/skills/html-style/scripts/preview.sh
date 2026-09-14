#!/usr/bin/env bash
# 입력 파일에는 html·head·body 태그가 없어 미리보기용으로 붙인다.
set -euo pipefail

page="${1:?조립된 HTML 경로}"
dir="${2:-$(dirname "$page")}"
wrapped="$dir/.preview.html"

{
  printf '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
  printf '<style>body{margin:0;font:14px system-ui;background:#fafafa}img{max-width:100%%}[hidden]{display:none!important}</style></head><body>'
  cat "$page"
  printf '</body></html>'
} > "$wrapped"

if command -v pnpm >/dev/null && pnpm exec playwright --version >/dev/null 2>&1; then
  pw=(pnpm exec playwright)
else
  pw=(npx --yes playwright)
fi

url="file://$(cd "$(dirname "$wrapped")" && pwd)/$(basename "$wrapped")"
"${pw[@]}" screenshot --viewport-size=1280,800 --color-scheme=light --full-page --wait-for-timeout=1500 "$url" "$dir/light.png"
"${pw[@]}" screenshot --viewport-size=1280,800 --color-scheme=dark --full-page --wait-for-timeout=1500 "$url" "$dir/dark.png"
"${pw[@]}" screenshot --viewport-size=390,844 --color-scheme=light --full-page --wait-for-timeout=1500 "$url" "$dir/mobile.png"
printf '%s\n' "$dir/light.png" "$dir/dark.png" "$dir/mobile.png"
