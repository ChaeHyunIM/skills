@../agents/AGENTS.md

## Orchestration

Before writing or editing a Workflow script, and before spawning multiple subagents with the Agent tool, always invoke the `workflow-tiering` skill first. Assign `model` and `effort` per `agent()` call as two independent axes — never let the session model cascade to every stage.

`/code-review` is no exception when it generates a local workflow. Invoke `workflow-tiering` before creating the script and apply the five-stage assignment (Scope · Find · Verify · Sweep · Synthesize) from that skill's `/code-review` section. A level passed by the user (high · xhigh · max) is a **ceiling**, not a flat value for every stage.

## Creating a new skill — home is `chimstack/agents/` in the skills repo

The skills repo (`~/Desktop/skills`) holds **only skills the user wrote**, under `chimstack/`. Claude Code runs **alongside other coding agents** (Codex and others), so a new skill's canonical copy lives in the runtime-neutral `chimstack/agents/<name>/`. It reaches the runtimes through `~/.agents/skills/<name>` (a symlink into the repo), and `~/.claude/skills/<name>` is a relative symlink to that. This holds even when `/skill-creator` is invoked — if the skill-creator skill says to write directly into `~/.claude/skills/` or `~/.agents/skills/`, this rule wins.

```bash
mkdir -p ~/Desktop/skills/chimstack/agents/<name>
ln -s ~/Desktop/skills/chimstack/agents/<name> ~/.agents/skills/<name>
ln -s ../../.agents/skills/<name> ~/.claude/skills/<name>
```

`~/.agents/skills/` itself is a **real directory**: skills installed from others (`npx skills`) live there as real files and are never copied into the repo. When the user adds someone else's skill, record its source and chosen skill names in the repo's `external/README.md` instead. A chimstack skill that reads an external one points at `~/.agents/skills/<name>/SKILL.md`, not a relative path — external skills are outside the repo.

### Exception — Claude-specific skills go in `chimstack/claude/`

If a skill depends on **functionality that only exists in Claude Code**, create it under `chimstack/claude/<name>/` and link `~/.claude/skills/<name>` straight to it (not through `~/.agents/skills`, or Codex would pick it up). The single test is: «would this skill still work in another runtime?» Any one of the following makes it Claude-specific:

- The skill drives Workflow tool scripts, Agent subagents, or Artifacts
- It relies on nested-session tricks such as `claude -p` or `--output-format stream-json`
- It calls a Claude Code built-in slash command like `/code-review`
- It assumes Claude Code hooks, plugins, or `.claude/settings.json`

`~/.agents/.skill-lock.json` holds the install records of external skills (machine state, not in the repo). Two pitfalls when reading this layout:

- **`agents/openai.yaml` says nothing about Claude.** It is the portable-skill manifest other runtimes read (`interface`, `policy.allow_implicit_invocation`). Claude Code reads only `disable-model-invocation` in the SKILL.md frontmatter, so one folder can carry different policies per runtime. Never conclude "this is blocked in Claude" from that file.
- **Same name ≠ same skill.** A skill in `~/.agents/skills/` can share its name with an unrelated one elsewhere. Open both before calling one an outdated copy.

Also note `find ~/.claude/skills -maxdepth 2` does not follow symlinks — use `-L` or `readlink -f` first.

## Never print secrets

Never `cat` / `Read` a secret file — `.env`, `.env.local`, `.dev.vars`, `.dev.vars.local`. **A masking `sed` is not an exception**: an incomplete pattern leaks the real value into the transcript, and once it is in the log, rotation is the only remedy.

Work without reading the values instead:
- Counting or listing keys: `grep -c`, `grep -oE '^[A-Z_]+='`.
- Editing or renaming: `sed -i ''` in place — no output.
- If a value genuinely must be known, ask the user for it. Do not print it.

## Billable work stays inside the approved scope

For anything that costs money (Cloudflare Images transformations, paid API calls, bulk storage), the approved scope is **the exact target the user named**. "Just run it all at once" approves the axis under discussion, not an adjacent one (another format, table, or surface). Finding a gap mid-task is not authorization to widen.

When an extra target appears, keep the order: (1) confirm from the code that a real consumer exists, (2) compute the cost, (3) report and get approval — then bake. "Completeness" and "while we're at it" are not reasons. Report the remainder as a list instead.

Why this is a hard rule: Images bills per unique transformation at request time, and deleting the output refunds nothing. A format no client requests is pure spend — the web `<picture>` serves `<source type="image/avif">` with a webp `<img>` fallback, so avif-capable browsers never request webp.
