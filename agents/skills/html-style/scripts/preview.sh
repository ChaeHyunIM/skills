#!/usr/bin/env bash
# 조립된 파일을 브라우저 골격으로 감싸 라이트·다크·모바일 스크린샷 3장을 찍는다.
# 게시 전 한 번만 본다. 반복 루프를 돌리지 않는다.
#
#   scripts/preview.sh out.html [출력 디렉토리]
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
"${pw[@]}" screenshot --viewport-size=1280,800 --full-page --wait-for-timeout=1500 "$url" "$dir/light.png"
"${pw[@]}" screenshot --viewport-size=1280,800 --color-scheme=dark --wait-for-timeout=1500 "$url" "$dir/dark.png"
"${pw[@]}" screenshot --viewport-size=390,844 --wait-for-timeout=1500 "$url" "$dir/mobile.png"
printf '%s\n' "$dir/light.png" "$dir/dark.png" "$dir/mobile.png"
