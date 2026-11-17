# skills

Claude Code · Codex 등 여러 코딩 에이전트가 읽는 글을 모은 저장소. 스킬과 전역 지침 문서다.
원래 [dotfiles](https://github.com/ChaeHyunIM/dotfiles) 안에 있었는데 떼어냈다.

가르는 기준은 **읽는 주체**다. 에이전트가 읽고 그대로 행동하는 글은 여기 오고, 런타임이
파싱해 기능을 켜고 끄는 값은 dotfiles 에 남는다. 그래서 `CLAUDE.md` 는 여기 있고
`settings.json` 은 저기 있다. 플러그인 목록·MCP 서버·테마는 에이전트에게 하는 말이 아니다.

## 구조

```
chimstack/                      직접 만든 스킬 (internal)
  agents/                       런타임 중립 — 어느 에이전트에서도 돈다
  claude/                       Claude Code 전용 — Workflow · Agent · Artifact 에 의존
external/
  README.md                     받아온 스킬의 출처·설치 명령 (파일은 두지 않는다)
agents/
  SOUL.md                       채현의 말투·소통 방식 공통 원본
claude/
  CLAUDE.md                     Claude Code 전역 지침
codex/
  AGENTS.md                     Codex 전역 지침
```

**internal 과 external** — 직접 만든 스킬만 `chimstack/` 에 둔다. 남이 만든 스킬은 파일을 들고 있지 않고
`external/README.md` 에 출처와 설치 명령만 적는다. 받은 스킬은 `skills` CLI 나 플러그인이 설치·갱신하고,
설치 기록(`~/.agents/.skill-lock.json`)도 그 도구 몫이다.

**chimstack 안에서 정본과 런타임 전용을 나누는 기준** — Workflow · Agent · Artifact 처럼 그 런타임에만 있는
기능에 기대면 전용이다. 옮겨봐야 다른 데서 안 돈다. 그 외에는 전부 `chimstack/agents/` 에 두고 여러 런타임이 같이 쓴다.

`agents/SOUL.md`는 다른 사람에게 전달할 글을 쓸 때 읽는 공통 문서다. Slack·DM,
이슈·PR 본문과 코멘트, 리뷰 답글, 공지, 복사해 보낼 초안에 적용한다. 별도 호출 스킬로
만들지 않고 Codex·Claude 전역 지침에서 연결해 전용 스킬 없이 작성할 때도 읽게 한다.
chimstack 스킬(`agent-loop` 계약, `write-pr`)은 이 파일을 가리키지 않고
"사용자 지침이 지정한 말투 문서가 있으면 읽는다"고만 적는다. 그래서 다른 사람은 자기 말투 문서를 전역 지침에 연결해 쓴다.
필수 양식과 사실관계를 보존하면서 말투에 적용하며, 게시 승인 규칙은 별도로 따른다.
상대 링크는 심볼릭 링크를 따라간 원본 파일 위치를 기준으로 해석한다.

chimstack 스킬이 받아온 스킬을 읽을 때는 상대 경로가 아니라 설치 위치 `~/.agents/skills/<이름>/SKILL.md` 로 가리킨다.
받아온 스킬은 저장소 밖에 있어서 상대 경로로는 찾을 수 없다.

## 설치

설치 스크립트를 두지 않는다. 어느 경로에 어떤 이름으로 얹어야 그 런타임이 스킬을
인식하는지는 런타임마다 다르고, 버전이 오르면 또 바뀐다. 그 규칙을 스크립트에 박아 두면
저장소가 런타임 변경을 계속 쫓아다녀야 한다.

클론하고, 경로가 고정인 것들만 손으로 링크한다.

```bash
git clone https://github.com/ChaeHyunIM/skills.git ~/skills

# 지침 문서
ln -sfn ~/skills/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sfn ~/skills/codex/AGENTS.md ~/.codex/AGENTS.md
```

`-f` 는 목적지를 말없이 지운다. 이미 뭔가 있는 머신이라면 `ls -la` 로 먼저 본다.
심링크면 덮어써도 되고, 실파일이면 옮겨 두고 건다.

**스킬은 그 런타임의 에이전트가 얹는다.** Claude Code 든 Codex 든 켜고 이렇게 말하면 된다.

```
~/skills/chimstack/agents 가 런타임 중립 스킬 정본이고,
~/skills/chimstack/claude 는 Claude Code 전용이다.
~/skills/external/README.md 는 받아올 스킬 목록이다.
받아올 스킬을 먼저 설치하고, chimstack 스킬은 지금 런타임이 스킬을 읽는 방식대로 링크해줘.
```

참고로 이 머신은 이렇게 걸려 있다.

- `~/.agents/skills/` 는 실제 디렉터리다. 받아온 스킬은 실파일로, `chimstack/agents/<이름>` 은 스킬마다 절대 경로 심링크로 들어간다.
- `~/.claude/skills/<이름>` 은 `../../.agents/skills/<이름>` 상대 심링크다. Claude 전용은 `chimstack/claude/<이름>` 을 직접 가리킨다.
- Codex 는 중립 스킬을 `~/.agents/skills` 에서 읽는다.

### 권장 도구

chimstack 스킬이 실행하는 명령줄 도구다. 스킬은 없는 도구를 새로 설치하지 않으므로 사람이 미리 깔아 둔다.

| 도구 | 쓰는 곳 | 설치 |
|---|---|---|
| `gh` (로그인까지) | `write-pr` PR 저장·기록물 첨부, `agent-loop` 검증 커밋 확인 | `brew install gh` → `gh auth login` |
| ImageMagick | `write-pr` PR 이미지에 번호·화살표 표시 | `brew install imagemagick` |
| Node | `write-pr` 이미지 표시 스크립트 | nvm 등으로 설치 |
| `pnpm` | `write-pr` call tree 추출(`calldiff`) | `brew install pnpm` |

## 스킬을 새로 만들 때

정본이 기본값이다. `chimstack/agents/<이름>/SKILL.md` 로 만들고 `~/.agents/skills/<이름>` 에 심링크를 건다.
Claude Code 전용 기능에 기대야만 `chimstack/claude/` 로 보낸다.

남의 스킬을 받으면 파일을 여기 넣지 않고 `external/README.md` 에 출처와 고른 스킬을 적는다.

## dotfiles 와의 관계

dotfiles 는 이제 스킬을 갖지 않는다. 두 저장소는 서로를 참조만 하고 서브모듈로 묶지 않는다 —
새 머신에서는 둘 다 클론하고, `install.sh` 는 dotfiles 만 돌린다.
스킬은 「설치」 절의 링크와 에이전트가 맡는다.
