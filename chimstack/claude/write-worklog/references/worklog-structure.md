# Worklog Structure · Quality Bar

Always read this file before writing a worklog. The skeleton, per-section
how-to, quality bar, and commit format are all here. The goal is **not a flat
list of facts** but an **engineer's wiki page that re-onboards with zero
warm-up weeks later**.

NOTE: these instructions are in English, but the worklog OUTPUT is in **Korean**.
The Korean strings inside the templates and examples below (section headers like
`배경`, `결정`, `구현`, `핵심 개념`, `디버깅`; the good/bad concept example;
labels like `증상(Symptom)`) are literal output — emit them as shown. Keep
technical terms and English-natural concepts in English.

## Table of contents
1. [Output location & file rules](#1-output-location--file-rules)
2. [Document skeleton](#2-document-skeleton)
3. [Commit-reference format](#3-commit-reference-format)
4. [Per-section how-to & quality bar](#4-per-section-how-to--quality-bar)
5. [Variations by session type](#5-variations-by-session-type)
6. [Tone & language rules](#6-tone--language-rules)

---

## 1. Output location & file rules

- Path: `~/Desktop/worklog/YYYY-MM-DD.md` — **one file per day**. Date comes from runtime (`worklog_context.sh`'s `DATE`).
- The date is **the day the work happened**: today for the current session, or the session's own date (the digest's `Session date (KST)`) when documenting a past transcript. Never file past work under today's date.
- Create the directory if it doesn't exist.
- **MODE=create**: new file. One H1 day title at the top, then the session block below it.
- **MODE=append**: a second session on the same day. Do not overwrite — **append** a `---` divider + the new session block at the very end. Do not re-emit the H1 day title.
- Heading-level convention (fixed so append never breaks):
  - `#` = the day (`# 2026-06-09 워크로그`) — once per file
  - `##` = one session (`## 안드로이드 formSheet 스크롤 누수 수정`)
  - `###` = a section within the session (배경 / 결정 / 구현 / 개념 / 디버깅 / 검증 / 메모)
  - `####` = an item within a section (an individual concept, an individual bug)

## 2. Document skeleton

The skeleton of one session block. Numbers and titles are **illustrative only** —
drop sections the session lacks entirely (no empty sections), reorder them, or
rename them (as in §5). Renumber the remaining sections from 1 (no gaps).

```markdown
## <세션 제목 — 한 줄로 무엇을 했는지>

> <2~4줄 요약 blockquote: 무엇에서 출발해 무엇을 바꿨고 왜 중요한지.>
> <적용/배포 시점 같은 주의가 있으면 한 줄 더.>

**작성 시각:** HH:MM · **브랜치:** `main` · **세션 ID:** `51449aee-9b79-4a64-af5b-c509adb63538`

> 📌 커밋 참조: `abc1234` — feat: ... (2026-06-09 14:32)

### 1. 배경 — 왜 손댔나
<이 작업을 촉발한 보고/관찰/지표. 동기를 한 단락.>

### 2. 결정 — 무엇을 두고 고민했나
<선택지·트레이드오프·최종 결정과 근거. 표로.>

### 3. 구현 — 무엇을 바꿨나
<변경 요약 표 + 핵심 코드 + 왜 이렇게 짰는지.>

### 4. 핵심 개념
<이 세션에 등장한 비자명 개념을 회상 최적화로 설명.>

### 5. 디버깅 — <버그 한 줄>
<증상 → 가설 → 조사 → 근본 원인 → 해결.>

### 6. 검증
<어떻게 확인했나. 수동 검증 트릭 포함.>

### 7. 메모 / 남은 것
<커밋에서 뺀 것, 보류한 것, 후속 과제.>
```

The title, summary blockquote, and 배경 are **the narrative's starting point**.
Plant "where this started from" first so the later sections read as cause-and-effect.

**세션 ID** — always include it in the meta line, sourced per input mode:
current-session mode uses `worklog_context.sh`'s `SESSION_ID` output
(`CLAUDE_CODE_SESSION_ID`); explicit-file mode uses the digest header's
`Session ID` (the transcript's `<uuid>.jsonl` filename). If somehow unavailable
in either mode, omit the `· **세션 ID:** ...` segment rather than writing a
placeholder — never fabricate one.

## 3. Commit-reference format

- At runtime, `worklog_context.sh` gives recent commits as `hash|date|author|subject`.
- Pick only commits **actually produced by this session** (matching its topic/time). Do not cite pre-session or unrelated commits.
- Put a one-line meta line **directly under** the header of any section that produced code changes (implementation/decision/debugging):

  > 📌 커밋 참조: `a1b2c3d` — refactor(mobile): 저장 폴더 시트를 탭 즉시저장으로... (2026-06-08 19:30)

- Multiple commits in one section → list them in ascending time order.
- 7-char short hash. The message may be trimmed if long, but keep type·scope.
- **Not a git repo**, or a pure-exploration session (zero commits) → **silently omit** this line. Do not write filler like "no commits".
- To add file count / churn (`(7 files, +114/−68)`), confirm with `git show --stat <hash>` and append it after the message. Optional.

## 4. Per-section how-to & quality bar

### 4.1 Decision — what counts as a "decision" vs a "side comment"

Signals of a decision worth recording:
- Multiple options were genuinely weighed (A vs B, with adopt/reject rationale)
- A non-obvious or counter-intuitive choice — one that later prompts "why this way?"
- A point where the user changed or locked direction ("let's do this", "drop that")
- A branch with a trade-off (performance vs simplicity, additive vs shape-change, etc.)

Side comments to **drop**: an idea mentioned once and never used, trivial naming,
a fleeting guess reversed on the next line, the mechanical steps of tool use.

Put trade-offs in a table. Mark the adopted one with **(채택)** and put its rationale in the same row.

```markdown
| 선택지 | 장점 | 단점 | 판정 |
|---|---|---|---|
| 클라에서 추출 | 서버 부하 0 | 백필 불가·검증 불가 | |
| 서버 FFmpeg | 정본·백필 가능 | 서버 비용 | **(채택)** 썸네일 스푸핑 차단이 결정타 |
```

### 4.2 Implementation — what / why / embedded concept

Each implementation carries three things:
1. **What** it did — a change summary (a table if there are several)
2. **Why this way** — the reason this was chosen over alternatives (rationale)
3. The **concept embedded** in the code — if a non-trivial pattern shows up, what it is and why it matters, expanded in §4.3

If the change spans several files/items, lead with a table so the whole picture lands first:

```markdown
| # | 변경 | 효과 |
|---|---|---|
| 1 | `完了` 버튼 제거 → 폴더 탭 = 즉시 저장 | 무피드백 실패 원천 제거 |
| 2 | 멤버십 훅에 optimistic + 롤백 | 탭 즉시 반영, 실패 시 되돌림 |
```

Quote the key code, but with **inline comments on what/why each line does**:

```ts
onMutate: async ({ collectionId, add, remove }, { client }) => {
  await client.cancelQueries({ queryKey: key });   // ① 진행 중 refetch 취소 (안 하면 늦은 응답이 덮어씀)
  client.setQueryData(key, (old) => /* ② 이전 캐시 기반 토글 */);
},
```

Close with a per-file change table (`| 파일 | 변경 |`) so "what got touched" is visible at a glance.

### 4.3 Concept Explanation — the most important section

**Long-term value comes from here. Lean detailed over terse.** Not a wiki-style
definition — write as if **re-explaining to yourself after forgetting everything**.

Recipe (in this order):
1. **Plain language first** — one sentence for the intuition, then layer in technical precision.
2. **Ground it in what was built this session** — no abstract definitions. Tie it to real code: "이 앱의 `/i` 라우트가 이 방식", "우리 `onSettled`의 `=== 1` 가드가 이거".
3. **Why it exists** — the problem this concept solves; what breaks without it.
4. **Gotcha / misconception** — explicitly call out the trap or confusion actually hit this session. This is the heart of the recall value.

Quality contrast:

> ❌ Weak (wiki-style):
> "`cancelQueries`는 진행 중인 쿼리를 취소하는 React Query 메서드다."

> ✅ Strong (recall-optimized):
> **`cancelQueries`의 역할** — optimistic update를 캐시에 박기 직전, 같은
> 키로 날아가던 refetch를 취소한다. 안 하면: 방금 그린 낙관적 체크 위로
> **늦게 도착한 서버 응답이 옛 값을 덮어써** 체크가 깜빡인다. 그래서
> `onMutate` 안에서 `setQueryData` **직전에 반드시** 부른다. 이번에 연속 탭
> 깜빡임을 디버깅하다 이 순서가 곧 계약임을 확인했다.

If there are several concepts, split them under `#### 4.x <concept name>`. If an
external source (blog/doc) was the basis, leave the link (`> 참고: https://...`).
Scope each concept **to the session context** — don't cover every facet, only the
facet this session touched, but deeply.

### 4.4 Debugging — symptom → hypothesis → investigation → root cause → fix

If there was a bug, use this fixed 5-step structure. The **reasoning path** from
surface symptom to root cause must survive so the next one of this kind is fast to spot.

```markdown
### N. 디버깅 — <버그 한 줄 요약>

> 📌 커밋 참조: `05fa2a2b` — fix: ... (2026-06-06 15:10)

**증상(Symptom)** — <무엇이 어떤 입력에서 어떻게 잘못 보였나.>
**가설(Hypothesis)** — <떠올린 원인 후보들. 어떤 걸 먼저 의심했나.>
**조사(Investigation)** — <무엇을 확인했고 무엇을 배제(ruled out)했나. 결정적 단서.>
**근본 원인(Root Cause)** — <진짜 원인. 보통 표면 증상과 다른 층에 있다.>
**해결(Fix)** — <어떻게 고쳤나. 왜 이 픽스가 맞나.>
```

- Record the **ruled-out hypotheses** too — "X는 아니었다(30일 0건 확인)" saves the next investigation's time.
- Put the decisive clue (a log line, a pattern) into a code block verbatim.
- If the cause differed from the first diagnosis (a reversal), that fact is itself worth recording → a correction blockquote near the top.

### 4.5 Narrative — wiring sections as cause-and-effect

Make the flow visible, not a flat list. Surface how the elements actually
connected across the session with connective sentences between sections:

> "서버 실패(b)를 배제하자 남은 건 UX 함정(a)뿐이었고(→ 디버깅), 이게 §3의
> 탭 즉시저장 결정으로 이어졌다. 그 구현이 연속 탭 깜빡임을 드러냈고(→ 디버깅
> 2), 고치는 과정에서 concurrent optimistic 개념(→ §4.3)이 분명해졌다."

Typical chain: **decision → implementation → (revealed) bug → fix → concept
clarified**. Open with 배경, close with 메모 / 남은 것.

## 5. Variations by session type

- **Implementation-focused (no bug)**: 배경 → 결정 → 구현 → 개념 → 검증 → 메모. Omit the debugging section.
- **Debugging-focused (little new implementation)**: 배경 → 디버깅(증상→…→해결) → 개념(버그가 가르쳐준 것) → 메모. Keep the implementation section to just the fix.
- **Mixed**: the full §2 skeleton. Weave decision↔implementation↔bug with narrative.
- **Pure exploration (zero commits)**: decision/concept-heavy, omit commit refs, replace "구현" with "조사 결과".

## 6. Tone & language rules

- **Language: Korean.** But keep technical terms, library/framework names, and English-natural concepts in English (hydration, stale closure, idempotency, optimistic, onMutate, thundering herd, etc.). No forced translation.
- Tone: technical but readable — an engineer's internal wiki, not a dry log dump.
- Headers carry meaning ("배경 — 왜 손댔나" yes, "섹션 2" no).
- Use tables liberally (option comparison, verdicts, per-file changes, final summaries).
- Inline code comments are **WHY**-oriented (don't restate the what that identifiers already say).
- Do not state speculation as fact. If the transcript never confirmed it, omit it or mark it "추정".
