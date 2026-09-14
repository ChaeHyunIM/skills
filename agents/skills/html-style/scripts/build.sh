#!/usr/bin/env bash
# 큰 CSS와 내장 폰트 데이터를 에이전트가 읽지 않아도 되도록 여기서 파일을 이어 붙인다.
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
