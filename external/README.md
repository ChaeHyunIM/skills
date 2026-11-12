# external

다른 사람이 만든 스킬을 어디서 어떻게 받는지 적은 목록이다. 스킬 파일은 이 저장소에 두지 않는다.

- 설치 위치: `~/.agents/skills/` (실제 디렉터리). 직접 만든 스킬은 같은 곳에 `chimstack/`을 가리키는 심링크로 들어간다.
- 설치 기록: `~/.agents/.skill-lock.json`. `skills` CLI가 쓰는 이 머신의 상태라서 저장소에 넣지 않는다.
- 새 머신에서는 에이전트에게 "external/README.md대로 설치해줘"라고 하면 된다.

## 원칙

서비스 제공사가 직접 배포하는 원본에 붙는다. AI사 마켓플레이스를 한 번 거친 사본은 원본보다 뒤처지거나,
같은 스킬을 다른 이름으로 한 벌 더 싣고 오는 경우가 있었다. 예를 들어 Codex의 Cloudflare 앱은 원본 22개 중 13개만 실었고, 이름 앞에 `app-…` ID가 붙어 나왔다.

- **스킬**은 제공사의 스킬 레포를 `npx skills`로 받는다. `~/.agents/skills`에 한 벌만 두고 두 런타임이 같이 쓴다.
- **MCP**는 계정 단위 커넥터가 있으면 그쪽을 쓴다. Claude는 claude.ai 커넥터가 웹·데스크톱·클라우드·로컬에 모두 따라온다.
  Codex는 클라우드 작업에서 ChatGPT 앱(커넥터)이 동작하지 않아서, 제공사 안내대로 `codex mcp add`로 로컬에 등록한다.
- **플러그인**은 스킬과 MCP 말고 다른 것이 있을 때만 쓴다. 예를 들어 Expo 플러그인에는 훅이 들어 있다.

## `skills` CLI

[vercel-labs/skills](https://github.com/vercel-labs/skills). 레포에서 고른 스킬만 받는다.

```bash
npx skills add <출처> -g -y --skill <스킬> <스킬> …
npx skills update -g          # 받은 스킬 전부 갱신
```

| 출처 | 고른 스킬 |
|---|---|
| [emilkowalski/skill](https://github.com/emilkowalski/skill) | 전부 (`--skill '*'`) |
| [planetscale/skills](https://github.com/planetscale/skills) | 전부. 공식 README대로 `npx skills add planetscale/skills -g -y` |
| [planetscale/database-skills](https://github.com/planetscale/database-skills) | postgres |
| [cloudflare/skills](https://github.com/cloudflare/skills) | 전부. Codex에만 받는다 (아래 Cloudflare 절) |
| [mobbin/skills](https://github.com/mobbin/skills) | 전부. 공식 README대로 `npx skills add mobbin/skills -g -y`. MCP는 Claude가 claude.ai 커넥터, Codex가 `codex mcp add`로 붙인다 |
| [cursor/plugins](https://github.com/cursor/plugins) | create-verification-skill, maintain-verification-skill |
| [softaworks/agent-toolkit](https://github.com/softaworks/agent-toolkit) | react-useeffect |
| [deckardger/tanstack-agent-skills](https://github.com/deckardger/tanstack-agent-skills) | tanstack-query-best-practices |
| [vercel/turborepo](https://github.com/vercel/turborepo) | turborepo |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | web-design-guidelines |
| [GoogleChrome/modern-web-guidance](https://github.com/GoogleChrome/modern-web-guidance) | modern-web-guidance |
| [mattpocock/skills](https://github.com/mattpocock/skills) | handoff |
| [humanlayer/skills](https://github.com/humanlayer/skills) | show-me |
| [dmmulroy/anti-slop](https://github.com/dmmulroy/anti-slop) | install-anti-slop |

### cursor/plugins의 검증 스킬 두 개

`create-verification-skill` · `maintain-verification-skill`은 원본을 고치지 않는다. 원본은 프로젝트 검증 스킬을
`.cursor/skills/`에 만들고 찾지만 우리는 `.agents/skills/`를 쓴다. 이 차이는 전역 지침(`claude/CLAUDE.md`,
`codex/AGENTS.md`)과 `agent-loop` 계약에서 `.cursor/skills/`를 `.agents/skills/`로 바꿔 읽게 해서 맞춘다.
그래서 `npx skills update`로 그대로 갱신해도 된다.

받을 때는 `pstack/skills/` 경로를 직접 준다. 이름만 주면 같은 레포의 Claude Code용 사본(`harness/pstack/claude-code/`)이
잡히는데, 이 사본은 스킬 폴더 밖의 문서를 읽으라고 해서 링크가 깨진다.

```bash
npx skills add https://github.com/cursor/plugins/tree/main/pstack/skills/create-verification-skill -g -y
npx skills add https://github.com/cursor/plugins/tree/main/pstack/skills/maintain-verification-skill -g -y
```

### chimstack이 기대는 스킬

아래 스킬은 `chimstack/` 스킬이 `~/.agents/skills/<이름>/SKILL.md`로 직접 읽는다. 지우면 그쪽이 깨진다.

- `code-quality` → postgres, react-useeffect, tanstack-query-best-practices, modern-web-guidance, web-design-guidelines, turborepo
- `write-pr` → show-me

## Rex

[Rex](https://www.superlogical.com/rex/)는 `rex` 명령으로 스킬과 세션 시작 훅을 같이 깐다.
스킬 파일에는 내용이 거의 없고, 쓸 때마다 `rex`에서 안내문을 받아 온다. 그래서 Rex만 업데이트하면 스킬 내용도 같이 바뀐다.

```bash
rex skill setup      # 이 머신에서 찾은 에이전트 전부에 스킬과 훅 설치. 다시 돌려도 안전하다
rex skill status     # 설치 상태 확인
```

| 에이전트 | 스킬 | 훅 |
|---|---|---|
| Claude Code | `~/.claude/skills/rex` | `~/.claude/settings.json` |
| Codex · OpenCode · Pi | `~/.agents/skills/rex` | Codex만 `~/.codex/hooks.json` |

세션 이름을 작업에 맞게 붙이는 `--session-naming`은 쓰지 않는다.

## 플러그인

플러그인은 런타임이 설정 파일을 읽어 켜고 끈다. 여기에는 무엇을 쓰는지만 적고, 켜고 끄는 값은 각 설정 파일이 정본이다.

**Claude Code** — `~/.claude/settings.json`의 `enabledPlugins`

| 마켓플레이스 | 플러그인 |
|---|---|
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | figma, typescript-lsp |

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install figma@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
```

**Codex** — [dotfiles](https://github.com/ChaeHyunIM/dotfiles)의 `codex/config.toml`

| 마켓플레이스 | 플러그인 |
|---|---|
| [expo/skills](https://github.com/expo/skills) | expo |
| [getsentry/plugin-codex](https://github.com/getsentry/plugin-codex) | sentry |

Expo 플러그인의 `expo-animation`은 Emil Kowalski와 같이 만든 스킬이라 위 emilkowalski의 `animate-expo`와 내용이 같다.
Claude에는 Expo 플러그인이 없으니 `animate-expo`를 그대로 쓰고, Codex에서만 같은 설정 파일의 `[[skills.config]]`로
`~/.agents/skills/animate-expo/SKILL.md`를 끈다.

### PlanetScale

스킬의 정본은 위 `planetscale/skills` 하나다. Codex용 플러그인 [planetscale/codex-plugin](https://github.com/planetscale/codex-plugin)은
같은 스킬을 `planetscale-` 접두사 없는 이름으로 한 벌 더 싣고 있어서, 깔면 Codex에 15쌍이 두 번 잡힌다. 그래서 쓰지 않는다.

그 플러그인에 같이 들어 있던 MCP는 [공식 안내](https://planetscale.com/docs/agent-setup/prompt)대로 따로 등록한다.
처음 등록할 때 브라우저에서 OAuth 인증을 한 번 거친다.

```bash
codex mcp add planetscale --url https://mcp.pscale.dev/mcp/planetscale
```

Claude Code는 claude.ai의 PlanetScale 커넥터로 연결돼 있어서 따로 등록하지 않는다.
CLI는 `pscale` 0.292.0 이상이 필요하고 `pscale auth check --format json`으로 인증을 확인한다.

### Cloudflare

[공식 agent setup 안내](https://developers.cloudflare.com/agent-setup/prompt.md)를 따른다. 원본은 `cloudflare/skills` 하나다.

**Claude Code**는 claude.ai에서 동기화되는 `cloudflare` 플러그인이 같은 레포의 스킬 22개와 Cloudflare MCP를 함께 싣고 있다.
안내의 `claude plugin install cloudflare@cloudflare`와 같은 내용이라 따로 설치하지 않는다. 또 설치하면 두 벌이 된다.

**Codex**는 안내의 명령에 `-a codex`를 붙여 Codex에만 받는다. 붙이지 않으면 `~/.claude/skills`에도 링크가 생겨서
Claude에서 플러그인의 `cloudflare:*`와 두 번 잡힌다.

```bash
npx -y skills add cloudflare/skills --skill '*' --yes --global -a codex
codex mcp add cloudflare --url https://mcp.cloudflare.com/mcp
codex mcp login cloudflare
```

ChatGPT의 Cloudflare 앱은 쓰지 않는다. 안내의 선택 항목인 `cf` CLI도 설치하지 않는다. 프로젝트에서 Wrangler를 쓴다.

## 기록하지 않는 것

도구가 직접 설치하고 갱신하는 것들이다.

- `~/.claude/skills/synced/`, `~/.claude/plugins/synced/` — claude.ai가 동기화
- `~/.codex/skills/.system/` — Codex 내장
