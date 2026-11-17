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
- **프로젝트 스택에 묶인 스킬·MCP**(Expo, Sentry, Cloudflare, PlanetScale 등)는 여기 적지 않는다. 쓰는 프로젝트의 README에 적는다.

## `skills` CLI

[vercel-labs/skills](https://github.com/vercel-labs/skills). 레포에서 고른 스킬만 받는다.

```bash
npx skills add <출처> -g -y --skill <스킬> <스킬> …
npx skills update -g          # 받은 스킬 전부 갱신
```

| 출처 | 고른 스킬 |
|---|---|
| [emilkowalski/skill](https://github.com/emilkowalski/skill) | 전부 (`--skill '*'`) |
| [planetscale/database-skills](https://github.com/planetscale/database-skills) | postgres |
| [mobbin/skills](https://github.com/mobbin/skills) | 전부. 공식 README대로 `npx skills add mobbin/skills -g -y`. MCP는 Claude가 claude.ai 커넥터, Codex가 `codex mcp add`로 붙인다 |
| [cursor/plugins](https://github.com/cursor/plugins) | create-verification-skill, maintain-verification-skill |
| [deckardger/tanstack-agent-skills](https://github.com/deckardger/tanstack-agent-skills) | tanstack-query-best-practices |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | web-design-guidelines, vercel-react-best-practices |
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

아래 스킬은 `chimstack/` 스킬이 읽는다.

- `write-pr` → show-me. `~/.agents/skills/show-me/SKILL.md`로 직접 읽으므로 지우면 깨진다.
- `code-quality` → postgres, tanstack-query-best-practices, modern-web-guidance, web-design-guidelines, vercel-react-best-practices, turborepo.
  turborepo는 Turborepo를 쓰는 저장소(doko-monorepo)에 프로젝트 스킬로 받고, 여기서는 받지 않는다.
  이름으로 찾고, 프로젝트의 `.agents/skills/`를 먼저 본 뒤 `~/.agents/skills/`를 본다. 프로젝트에 그 스택이 있는데 스킬이
  어디에도 없으면 그 기준 없이 검토가 끝난다.
