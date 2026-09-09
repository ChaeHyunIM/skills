# skills

Claude Code · Codex 등 여러 코딩 에이전트가 함께 쓰는 스킬 저장소. 원래
[dotfiles](https://github.com/ChaeHyunIM/dotfiles) 안에 있었는데, 스킬만 따로 떼어냈다.
설정과 스킬은 고치는 주기도 다르고 읽는 주체도 다르다 — 설정은 머신이, 스킬은 에이전트가 읽는다.

## 구조

```
agents/
  skills/             런타임 중립 정본 — 어느 에이전트에서도 돈다. → ~/.agents/skills
  .skill-lock.json    외부에서 받아온 스킬의 출처·해시 기록
claude/skills/        Claude Code 전용 — Workflow · Agent · Artifact 에 의존
codex/skills/         Codex 전용
```

**정본과 런타임 전용을 나누는 기준** — Workflow · Agent · Artifact 처럼 그 런타임에만 있는
기능에 기대면 전용이다. 옮겨봐야 다른 데서 안 돈다. 그 외에는 전부 `agents/skills/` 정본으로
두고 여러 런타임이 같이 쓴다.

`agents/skills/review-round` 처럼 정본 자리에 심링크가 서 있는 경우가 있다. 두 런타임이
같은 문서를 진입점만 바꿔 쓰는 스킬이라 원문은 한 벌만 둔다.

## 설치

설치 스크립트를 두지 않는다. 어느 경로에 어떤 이름으로 얹어야 그 런타임이 스킬을
인식하는지는 런타임마다 다르고, 버전이 오르면 또 바뀐다. 그 규칙을 스크립트에 박아 두면
저장소가 런타임 변경을 계속 쫓아다녀야 한다.

클론하고, 정본의 홈 자리만 링크한다.

```bash
git clone https://github.com/ChaeHyunIM/skills.git ~/skills
ln -sfn ~/skills/agents/skills ~/.agents/skills
ln -sfn ~/skills/agents/.skill-lock.json ~/.agents/.skill-lock.json
```

`~/.agents` 는 런타임 중립 홈이라 경로가 고정이다. 여기까지가 손으로 할 몫이다.

`-f` 는 목적지를 말없이 지운다. 새 머신이면 비어 있으니 그냥 치면 되고, 이미 뭔가 있는
머신이라면 `ls -la ~/.agents` 로 먼저 본다. 심링크면 덮어써도 되고, 실파일·실디렉터리면
옮겨 두고 건다.

**나머지는 그 런타임의 에이전트가 얹는다.** Claude Code 든 Codex 든 켜고 이렇게 말하면 된다.

```
~/skills/agents/skills 가 런타임 중립 스킬 정본이고,
~/skills/claude/skills 와 ~/skills/codex/skills 는 각 런타임 전용이다.
지금 런타임이 스킬을 읽는 방식대로 이것들을 설치해줘.
```

에이전트가 자기 규칙을 알고 있으니 심링크를 걸든 복사하든 알아서 맞춘다.

참고로 Claude Code 는 `~/.claude/skills/<이름>` 을 `../../.agents/skills/<이름>` 상대
심링크로 걸어 왔다. 정본은 그 링크가 `~/.agents/skills` 를 거쳐 자동으로 따라오고,
Claude 전용 3개만 이 저장소의 `claude/skills/` 를 직접 가리킨다.

## 스킬을 새로 만들 때

정본이 기본값이다. `agents/skills/<이름>/SKILL.md` 로 만들고, 런타임 전용 기능에 기대야만
`claude/` 나 `codex/` 로 보낸다. 전용으로 보냈다면 SKILL.md 맨 아래에 다른 런타임에서
무엇이 막혔는지 한 줄 남긴다.

## dotfiles 와의 관계

dotfiles 는 이제 스킬을 갖지 않는다. 두 저장소는 서로를 참조만 하고 서브모듈로 묶지 않는다 —
새 머신에서는 둘 다 클론하고, `install.sh` 는 dotfiles 만 돌린다.
스킬은 「설치」 절의 링크 두 줄과 에이전트가 맡는다.
