# Grouping Algorithm

## Phase 1: Change Extraction

Collect per-file diffs for the entire commit range:

```bash
git diff --name-status <start>^..<end>
git diff --stat <start>^..<end>
```

Build a map: `{ filePath → changeType (A/M/D/R) }`.

## Phase 2: Concern Classification

Classify each file into a concern using these heuristics (priority order):

1. **Package/app boundary** — `apps/<name>/` or `packages/<name>/` is the primary grouping key in a monorepo.
2. **Layer** — schema, API/route, service/logic, UI component, config, test, docs.
3. **Feature signal** — files sharing a keyword or directory subtree (e.g., `auth/`, `payment/`, `upload/`).
4. **Cross-cutting** — files that don't fit a single concern (shared types, utils, config). Group these as "chore" or attach to the dominant concern.

### Decision Rules

- If a file belongs to one app AND one feature → group by feature within that app.
- If a file is in `packages/` and only consumed by one app in this range → attach to that app's group.
- If a file is in `packages/` and consumed by multiple apps → separate "packages" commit.
- Config files (turbo.json, tsconfig, package.json) → "chore" group unless tightly coupled to a feature.

## Phase 3: Group Merging

After classification, merge small groups:

- Groups with ≤2 files → merge into the most related larger group.
- Target: 3-7 final groups for typical ranges. Fewer is better.

## Phase 4: Commit Ordering

Order groups by dependency (bottom-up):

1. Schema / DB changes
2. Shared packages
3. Backend / API
4. Frontend / UI
5. Config / chore

## Edge Cases

### Renamed Files
`git diff --name-status` shows `R` with old->new path. Group by the NEW path.

### Deleted Files
Group by the directory the file was in. If the entire directory is deleted, treat as a dedicated cleanup commit.

### Binary Files
Include in the same group as surrounding code files. Note in the commit message.

### Empty Groups
Drop silently. Don't create empty commits.

## Verification (Hard Gate)

After all commits are created:

```bash
git diff <new-HEAD> <original-end>
```

MUST produce empty output. If not, the reorganization is broken. Abort and report the diff.
