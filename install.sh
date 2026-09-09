#!/usr/bin/env bash
#
# 스킬 설치 — 런타임 중립 정본만 홈의 원래 자리로 심링크한다.
# 런타임 전용 스킬(claude/ · codex/)은 여기서 건드리지 않는다. README 「설치」 절.
#
set -euo pipefail

SKILLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.skills-backup/$(date +%Y%m%d-%H%M%S)"
linked=0
backed_up=0

# 목적지에 심링크가 아닌 실제 파일이 있으면 지우지 않고 백업으로 옮긴 뒤 링크한다.
link() {
  local src="$SKILLS/$1" dst="$HOME/$2"
  if [[ ! -e "$src" ]]; then
    echo "  건너뜀 (원본 없음): $1" >&2
    return
  fi
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mkdir -p "$(dirname "$BACKUP/$2")"
    mv "$dst" "$BACKUP/$2"
    backed_up=$((backed_up + 1))
  fi
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
  linked=$((linked + 1))
}

echo "==> 스킬 정본 (런타임 중립)"
link agents/skills            .agents/skills
link agents/.skill-lock.json  .agents/.skill-lock.json

chmod +x "$SKILLS"/*/skills/*/scripts/*.sh 2>/dev/null || true

echo
echo "링크 $linked 개 생성"
if (( backed_up > 0 )); then
  echo "기존 파일 $backed_up 개를 $BACKUP 로 옮김"
fi
echo
echo "남은 작업: 런타임 전용 스킬은 그 런타임의 에이전트에게 얹게 시킬 것 (README 「설치」 절)"
