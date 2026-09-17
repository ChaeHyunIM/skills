#!/usr/bin/env node
/**
 * 호출자가 준비하는 results.json의 입력 계약이다. 별도 타입 선언이 없어 선택 필드와 매체 형식을 함께 둔다.
 *
 *   node evidence-block.mjs --results results.json                       → 표준 출력에 검증 블록
 *   node evidence-block.mjs --results results.json --body-file body.md   → 검증 블록을 교체한 전체 본문
 *   node evidence-block.mjs --results results.json --attach-list         → 로컬 매체 경로를 한 줄씩 출력
 *
 * results.json
 * {
 *   "target": { "commit": "abc1234", "url": "https://github.com/o/r/commit/abc1234" },
 *   "base":   { "branch": "dev", "commit": "def5678" },            // 선택 사항
 *   "env":    "로컬 dev 서버 head(3000/4000)·base(3100/4100), Chromium 1280×800",
 *   "items": [
 *     {
 *       "text":   "이미 참여한 미션을 다시 누르면 '이미 참여 중' 안내가 표시된다",   // 완료 조건 원문
 *       "status": "충족",                                                 // 충족 | 미충족 | 미검증
 *       "detail": "apps/doko/e2e/mission-rejoin.spec.ts · head pass / base fail(버튼 없음)",
 *       "note":   "base 에서도 성립",                                      // 선택 사항
 *       "media": [                                                        // UI는 references/routes.md 기준 필수, 경로는 cwd 기준
 *         { "kind": "pair",  "label": "Desktop", "before": ".e2e/evidence/r1/c2-before.png", "after": ".e2e/evidence/r1/c2-after.png" },
 *         { "kind": "image", "label": "결과",    "file": ".e2e/evidence/r1/c2-result.png" },
 *         { "kind": "video", "label": "head",   "file": ".e2e/evidence/r1/c2-head.mp4" },
 *         { "kind": "video-pair", "label": "Desktop", "before": "…-base.mp4", "after": "…-head.mp4",
 *           "beforeUrl": "https://github.com/user-attachments/assets/…", "afterUrl": "…" }   // URL은 선택 사항
 *       ]
 *     }
 *   ],
 *   "rejected": [ { "reason": "로그인 페이지 캡처", "count": 1 } ]        // 선택 사항
 * }
 *
 * gh 첨부 경로는 cwd 안에 있어야 하고 공백을 포함할 수 없다. 이미지 png/jpg/gif/webp, 영상 mp4/mov/webm을 받는다.
 * GitHub가 플레이어로 표시하도록 영상은 독립된 줄에 둔다. video-pair는 업로드한 beforeUrl과 afterUrl이
 * 모두 있어야 HTML 표로 표시할 수 있다. 첨부 용량은 무료 요금제에 맞춰 각각 10 MB로 제한한다.
 */
import { existsSync, readFileSync, statSync } from "node:fs";
import { extname, relative, resolve } from "node:path";
import { parseArgs } from "node:util";

export const MARKER_START = "<!-- verify:start -->";
export const MARKER_END = "<!-- verify:end -->";
const HEADING = "## 완료 조건 검증";
const STATUSES = { 충족: { box: "x", label: "근거" }, 미충족: { box: " ", label: "결과" }, 미검증: { box: " ", label: "이유" } };
const IMAGE = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp"]);
const VIDEO = new Set([".mp4", ".mov", ".webm"]);
const CAP = 10 * 1024 * 1024;

function ref(file, cwd) {
  const rel = relative(cwd, resolve(cwd, file));
  if (rel === ".." || rel.startsWith("../")) throw new Error(`media must be inside the working directory: "${file}"`);
  if (/\s/.test(rel)) throw new Error(`media path cannot contain whitespace: "${file}"`);
  return `./${rel}`;
}

function checkFile(file, cwd, kinds) {
  const abs = resolve(cwd, file);
  if (!existsSync(abs)) throw new Error(`media file does not exist: "${file}"`);
  if (!kinds.has(extname(file).toLowerCase())) throw new Error(`unsupported media type: "${file}"`);
  if (statSync(abs).size > CAP) throw new Error(`over the 10 MB attachment cap: "${file}"`);
}

function attachmentUrl(value) {
  const u = new URL(value);
  if (u.protocol !== "https:" || u.hostname !== "github.com" || !u.pathname.startsWith("/user-attachments/assets/")) {
    throw new Error(`expected a https://github.com/user-attachments/assets/... URL: "${value}"`);
  }
  return u.href;
}

function suffix(label) { return label ? ` (${label})` : ""; }

function renderMedia(m, cwd, out) {
  switch (m.kind) {
    case "pair":
      checkFile(m.before, cwd, IMAGE); checkFile(m.after, cwd, IMAGE);
      out.push(`| Before${suffix(m.label)} | After${suffix(m.label)} |`, "|:---:|:---:|",
        `| ![Before](${ref(m.before, cwd)}) | ![After](${ref(m.after, cwd)}) |`, "");
      break;
    case "image":
      checkFile(m.file, cwd, IMAGE);
      out.push(`| ${m.label || "Preview"} |`, "|:---:|", `| ![${m.label || "Preview"}](${ref(m.file, cwd)}) |`, "");
      break;
    case "video":
      checkFile(m.file, cwd, VIDEO);
      out.push(`**${m.label || "영상"}**`, "", `![${m.label || "video"}](${ref(m.file, cwd)})`, "");
      break;
    case "video-pair":
      if (m.beforeUrl && m.afterUrl) {
        out.push("<table>", "  <tr>", `    <th>Before${suffix(m.label)}</th>`, `    <th>After${suffix(m.label)}</th>`, "  </tr>", "  <tr>",
          `    <td><video src="${attachmentUrl(m.beforeUrl)}" width="100%" controls></video></td>`,
          `    <td><video src="${attachmentUrl(m.afterUrl)}" width="100%" controls></video></td>`, "  </tr>", "</table>", "");
      } else {
        checkFile(m.before, cwd, VIDEO); checkFile(m.after, cwd, VIDEO);
        out.push(`**Before${suffix(m.label)}**`, "", `![Before](${ref(m.before, cwd)})`, "",
          `**After${suffix(m.label)}**`, "", `![After](${ref(m.after, cwd)})`, "");
      }
      break;
    default:
      throw new Error(`unknown media kind: "${m.kind}"`);
  }
}

export function renderBlock(results, { cwd = process.cwd() } = {}) {
  if (!Array.isArray(results.items) || results.items.length === 0) throw new Error("results.items must be a non-empty array");
  if (!/^[0-9a-f]{7,40}$/.test(results.target?.commit ?? "")) throw new Error("results.target.commit must be a Git SHA");
  if (results.target.url) {
    const url = new URL(results.target.url);
    if (url.protocol !== "https:" || !url.pathname.endsWith(`/commit/${results.target.commit}`)) {
      throw new Error("target URL must identify results.target.commit");
    }
  }
  const out = [MARKER_START, HEADING, ""];
  const target = results.target?.url ? `[${results.target.commit}](${results.target.url})` : results.target?.commit;
  if (!target) throw new Error("results.target.commit is required");
  const head = [`검증 대상: ${target}`];
  if (results.base?.branch) head.push(`base: ${results.base.branch}${results.base.commit ? `@${results.base.commit}` : ""}`);
  if (results.env) head.push(`환경: ${results.env}`);
  out.push(head.join(" · "), "");

  for (const item of results.items) {
    const s = STATUSES[item.status];
    if (!s) throw new Error(`unknown status "${item.status}" for "${item.text}"`);
    if (!item.text || !item.detail) throw new Error(`text and detail are required (${item.text ?? "?"})`);
    out.push(`- [${s.box}] ${item.text} — ${item.status}`, `  - ${s.label}: ${item.detail}`);
    if (item.note) out.push(`  - 참고: ${item.note}`);
    out.push("");
    for (const m of item.media ?? []) renderMedia(m, cwd, out);
  }

  if (results.rejected?.length) {
    const n = results.rejected.reduce((a, r) => a + (r.count ?? 1), 0);
    out.push(`거부한 증거 ${n}건: ${results.rejected.map((r) => `${r.reason}${r.count > 1 ? ` ×${r.count}` : ""}`).join(", ")}`, "");
  }
  out.push(MARKER_END);
  return `${out.join("\n").trim()}\n`;
}

export function attachList(results, { cwd = process.cwd() } = {}) {
  const files = [];
  for (const item of results.items) for (const m of item.media ?? []) {
    if (m.kind === "video-pair" && m.beforeUrl && m.afterUrl) continue;
    for (const f of [m.file, m.before, m.after]) if (f) files.push(ref(f, cwd));
  }
  return [...new Set(files)];
}

export function replaceBlock(body, block) {
  const start = body.indexOf(MARKER_START);
  const end = body.indexOf(MARKER_END);
  const headings = [...body.matchAll(/^## 완료 조건 검증[ \t]*\r?$/gm)];
  if (headings.length > 1) throw new Error("PR body contains more than one `## 완료 조건 검증` section");
  if (start !== -1 && end !== -1 && end > start) {
    if (body.indexOf(MARKER_START, start + MARKER_START.length) !== -1 || body.indexOf(MARKER_END, end + MARKER_END.length) !== -1) {
      throw new Error("PR body contains more than one verify marker block");
    }
    if (headings.length !== 1 || headings[0].index < start || headings[0].index > end) {
      throw new Error("verification heading must be inside the marker block");
    }
    // 마커 밖의 공백도 사람의 본문에 속하므로 trim하지 않는다.
    return body.slice(0, start) + block.trimEnd() + body.slice(end + MARKER_END.length);
  }
  if (start !== -1 || end !== -1) throw new Error("PR body contains an incomplete verify marker block");

  // 기존 수기 기록도 제목이 하나일 때만 같은 섹션으로 인계한다.
  if (headings.length === 1) {
    const from = headings[0].index;
    const next = body.slice(from + headings[0][0].length).search(/^#{1,2} /m);
    const to = next === -1 ? body.length : from + headings[0][0].length + next;
    return body.slice(0, from) + block.trimEnd() + "\n\n" + body.slice(to);
  }
  return body ? `${body}${body.endsWith("\n") ? "\n" : "\n\n"}${block}` : block;
}

function main(argv) {
  const { values } = parseArgs({ args: argv, options: { results: { type: "string" }, "body-file": { type: "string" }, "attach-list": { type: "boolean" } } });
  if (!values.results) throw new Error("--results <results.json> is required");
  const results = JSON.parse(readFileSync(values.results, "utf8"));
  if (values["attach-list"]) { process.stdout.write(attachList(results).map((f) => `${f}\n`).join("")); return; }
  const block = renderBlock(results);
  if (values["body-file"]) process.stdout.write(replaceBlock(readFileSync(values["body-file"], "utf8"), block));
  else process.stdout.write(block);
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").at(-1))) {
  try { main(process.argv.slice(2)); } catch (e) { console.error(String(e?.message ?? e)); process.exit(1); }
}
