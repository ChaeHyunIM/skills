#!/usr/bin/env bash
# 본문 HTML 하나를 게시용 단일 파일로 조립한다.
# CSS 세 파일은 여기서만 이어 붙이고 모델은 읽지 않는다 — 그래야 컨텍스트에 안 들어온다.
#
#   scripts/build.sh "<페이지 제목>" body.html out.html
set -euo pipefail

title="${1:?페이지 제목}"
body="${2:?본문 HTML 경로}"
out="${3:?출력 경로}"
here="$(cd "$(dirname "$0")/.." && pwd)"

{
  printf '<title>%s</title>\n<style>\n' "$title"
  cat "$here/assets/font.css" "$here/assets/brand.css" "$here/assets/page.css"
  printf '</style>\n'
  cat "$body"
} > "$out"

printf '%s (%s bytes)\n' "$out" "$(wc -c < "$out" | tr -d ' ')"
