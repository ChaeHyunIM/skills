## Orchestration

Before writing or editing a Workflow script, and before spawning multiple subagents with the Agent tool, always invoke the `workflow-tiering` skill first. Assign `model` and `effort` per `agent()` call as two independent axes — never let the session model cascade to every stage.

`/code-review` is no exception when it generates a local workflow. Invoke `workflow-tiering` before creating the script and apply the five-stage assignment (Scope · Find · Verify · Sweep · Synthesize) from that skill's `/code-review` section. A level passed by the user (high · xhigh · max) is a **ceiling**, not a flat value for every stage.

## Visual style for published pages

Before writing or editing an Artifact — or any standalone HTML page meant to be looked at — invoke the `brand-style` skill first. It holds the typography and icon rules, shared with Codex (where the same feature is called a site), so neither runtime carries its own copy.

## Creating a new skill — home is `~/.agents/skills/`

Claude Code runs **alongside other coding agents** (Codex and others). So a skill's canonical copy lives in the runtime-neutral home `~/.agents/skills/<name>/`, and `~/.claude/skills/<name>` is a **symlink** pointing there. This holds even when `/skill-creator` is invoked — if the skill-creator skill says to write directly into `~/.claude/skills/`, this rule wins. Most existing skills already follow this layout.

```bash
mkdir -p ~/.agents/skills/<name>
ln -s ../../.agents/skills/<name> ~/.claude/skills/<name>
```

Create the link with a **relative path** (`../../.agents/skills/<name>`) resolved from `~/.claude/skills/`, matching the existing links.

### Exception — Claude-specific skills go in `~/.claude/skills/` as real directories

If a skill depends on **functionality that only exists in Claude Code**, do not symlink it — create it directly under `~/.claude/skills/<name>/`. The single test is: «would this skill still work in another runtime?» Any one of the following makes it Claude-specific:

- The skill drives Workflow tool scripts, Agent subagents, or Artifacts
- It relies on nested-session tricks such as `claude -p` or `--output-format stream-json`
- It calls a Claude Code built-in slash command like `/code-review`
- It assumes Claude Code hooks, plugins, or `.claude/settings.json`

In that case, leave a **TODO for other runtimes** at the bottom of SKILL.md. No need to port it now — just record what is blocking it.

```markdown
## TODO — other runtimes

This skill lives in `~/.claude/skills/` because it depends on <specific Claude-only capability>.
How to substitute it in Codex or elsewhere is undecided.
```

`~/.agents/.skill-lock.json` holds the install records. Two pitfalls when reading this layout:

- **`agents/openai.yaml` says nothing about Claude.** It is the portable-skill manifest other runtimes read (`interface`, `policy.allow_implicit_invocation`). Claude Code reads only `disable-model-invocation` in the SKILL.md frontmatter, so one folder can carry different policies per runtime. Never conclude "this is blocked in Claude" from that file.
- **Same name ≠ same skill.** `~/.agents/skills/implement` was once an unrelated 15-line general skill while the loop's `implement` lived elsewhere. Open both before calling one an outdated copy.

Also note `find ~/.claude/skills -maxdepth 2` does not follow symlinks — use `-L` or `readlink -f` first.

## 사람이 읽는 코멘트는 승인받고 올린다

**팀원이 최소 1명 태그되어 읽어야 하는 글이면** — Linear 이슈 코멘트, PR 코멘트, Slack 메시지 무엇이든 — 에이전트가 직접 게시하지 않는다. 초안만 내놓고 사람의 승인을 받은 뒤에 올린다.

초안은 짧고 압축적으로, 사람이 말하듯 쓴다. 사용자가 그 문장을 그대로 복사해 쓸 수 없으면 실패한 초안이다. AI 가 쓴 티가 나는 긴 설명·라벨 나열·과잉 친절은 읽는 사람에게 해독 비용만 남긴다.

사람 태그 없이 순수 기록용으로 남기는 개발 이슈 로그는 예외 — 에이전트가 그냥 작성해도 된다. `/review-round` 가 PR 에 올리는 라운드 코멘트도 개발자끼리 보는 글이라 예외다.

## Never print secrets

Never `cat` / `Read` a secret file — `.env`, `.env.local`, `.dev.vars`, `.dev.vars.local`. **A masking `sed` is not an exception**: an incomplete pattern leaks the real value into the transcript, and once it is in the log, rotation is the only remedy. This happened on 2026-07-11 (`DATABASE_URL` for prod, AWS/R2 keys, `BETTER_AUTH_SECRET`, `APPLE_CLIENT_SECRET`, `GA4_SA_PRIVATE_KEY`).

Work without reading the values instead:
- Counting or listing keys: `grep -c`, `grep -oE '^[A-Z_]+='`.
- Editing or renaming: `sed -i ''` in place — no output.
- If a value genuinely must be known, ask the user for it. Do not print it.

## Billable work stays inside the approved scope

For anything that costs money (Cloudflare Images transformations, paid API calls, bulk storage), the approved scope is **the exact target the user named**. "Just run it all at once" approves the axis under discussion, not an adjacent one (another format, table, or surface). Finding a gap mid-task is not authorization to widen.

When an extra target appears, keep the order: (1) confirm from the code that a real consumer exists, (2) compute the cost, (3) report and get approval — then bake. "Completeness" and "while we're at it" are not reasons. Report the remainder as a list instead.

Why this is a hard rule: on 2026-08-04 an approved avif backfill (13,401 transforms) silently grew by 9,649 webp/video-thumbnail transforms ($4.8). Most of it was dead spend — the web `<picture>` serves `<source type="image/avif">` with a webp `<img>` fallback, so avif-capable browsers never request webp at all. Images bills per unique transformation at request time and deleting the output refunds nothing.

## Do not touch the git remote

Never rewrite a git remote URL, in particular not HTTPS → SSH. The user drives push/pull with lazygit but also opens GitHub Desktop, which breaks on an SSH remote. If a push fails, leave the remote alone and ask the user to push.
