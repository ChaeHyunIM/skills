# Ticket slicing rules

Read this when drawing slices in `to-tickets` step 4. The incidents behind these rules are in
`~/.agents/skills/agent-loop/references/evidence.md`.

## Contents

- [Vertical slices](#vertical-slices)
- [Blocking edges must be soft](#blocking-edges-must-be-soft)
- [Dependencies point down only](#dependencies-point-down-only)
- [Migrations hoist](#migrations-hoist)
- [Wide refactors are the exception](#wide-refactors-are-the-exception)

## Vertical slices

- **The unit of a slice is a FLOW** — one user-facing behaviour owned end to end, across every surface it
  touches (API, admin, app UI, web). Never split one flow across tickets by screen or by layer. A screen
  is a natural boundary only when exactly one flow lives there.
  The canonical mistake is splitting an auth-style flow into "API ticket / admin ticket / UI ticket /
  badge ticket": every fragment touches the same modules and none is demoable alone.
- Each slice cuts a **narrow but complete** path through every layer (schema, API, UI) — vertical, not a
  horizontal slice of one layer.
- A completed slice is demoable or verifiable on its own, and **merging it alone leaves the product
  consistent** — no orphaned entry points, no dangling references, no surface left "temporarily unused"
  until a sibling lands.
- Prefer one big ticket that owns a whole flow over small tickets that share one. Context-window sizing is
  secondary: a flow fragment that fits neatly is worth less than a complete flow that runs long.
- Any prefactoring is done first.

## Blocking edges must be soft

A blocking edge is **soft**: B builds on A's *merged* result, but each ticket is merge-consistent alone.

**A hard edge is not a dependency — it is one ticket cut in two. Fuse them.** An edge is hard when:

- merging B alone breaks the product,
- B cannot compile until A lands,
- A and B edit the same feature surface.

Litmus test: if you can already foresee the PR body saying "머지 순서 강제 — 먼저 머지하지 말 것",
"#X 머지 후 한 줄만 추가하면 닫힌다", or "이 diff 에서는 잠깐 소비처가 없다", the cut is wrong.

**The published set must be parallel-safe.** Tickets are implemented by concurrent agents in isolated
worktrees that know nothing of each other, so any two tickets not connected by a blocking edge must be
safe to implement simultaneously: no shared feature surface (the same domain modules, data layer, or
screen), and neither consumes a contract the other introduces.

## Dependencies point down only

Every route a ticket links to, symbol it imports, endpoint it calls must exist in **its own diff or in a
blocker's**. A dependency pointing at a *later* ticket cannot be sequenced away.

The concrete trap is an entry point without its destination: the tile, the chevron, the button that
navigates somewhere the next ticket will build. **Whoever builds the destination also wires the entry
point**; the earlier ticket renders it inert.

## Migrations hoist

Parallel tickets that each add a migration collide on the serial journal, and the collision is invisible
as text — only the apply order breaks.

When more than one slice needs schema changes, **hoist all schema work into a single preceding schema
ticket** that the flow tickets block on (a soft edge — the schema ticket merges alone), leaving the flow
tickets migration-free.

## Wide refactors are the exception

A **wide refactor** is one mechanical change — rename a column, retype a shared symbol — whose **blast
radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no
vertical slice can land green.

Don't force it into a tracer bullet; sequence it as **expand–contract**:

1. **expand** — add the new form beside the old so nothing breaks.
2. **migrate** — move call sites over in batches sized by blast radius (per package, per directory). Each
   batch is its own ticket blocked by the expand, and CI stays green batch to batch because the old form
   still exists.
3. **contract** — delete the old form once no caller remains, in a ticket blocked by every migrate batch.

When even the batches can't stay green alone, keep the sequence but let them share an integration branch
that all block a final integrate-and-verify ticket — green is promised only there.
