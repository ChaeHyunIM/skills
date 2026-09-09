#!/usr/bin/env node
/**
 * Renders the `## 완료 조건 검증` block for a PR body from results.json, and replaces it in place.
 * Node builtins only. Owns the `<!-- verify:start -->` / `<!-- verify:end -->` markers; everything
 * outside them is preserved byte for byte.
 *
 *   node evidence-block.mjs --results results.json                       → block on stdout
 *   node evidence-block.mjs --results results.json --body-file body.md   → full body with the block replaced
 *   node evidence-block.mjs --results results.json --attach-list         → local media paths, one per line
 *
 * results.json
 * {
 *   "target": { "commit": "abc1234", "url": "https://github.com/o/r/commit/abc1234" },
 *   "base":   { "branch": "dev", "commit": "def5678" },            // optional
 *   "env":    "로컬 dev 서버 head(3000/4000)·base(3100/4100), Chromium 1280×800",
 *   "items": [
 *     {
 *       "text":   "이미 참여한 미션을 다시 누르면 '이미 참여 중' 안내가 표시된다",   // verbatim condition
 *       "status": "충족",                                                 // 충족 | 미충족 | 미검증
 *       "detail": "apps/doko/e2e/mission-rejoin.spec.ts · head pass / base fail(버튼 없음)",
 *       "note":   "base 에서도 성립",                                      // optional
 *       "media": [                                                        // optional, paths relative to cwd
 *         { "kind": "pair",  "label": "Desktop", "before": ".e2e/evidence/r1/c2-before.png", "after": ".e2e/evidence/r1/c2-after.png" },
 *         { "kind": "image", "label": "결과",    "file": ".e2e/evidence/r1/c2-result.png" },
 *         { "kind": "video", "label": "head",   "file": ".e2e/evidence/r1/c2-head.mp4" },
 *         { "kind": "video-pair", "label": "Desktop", "before": "…-base.mp4", "after": "…-head.mp4",
 *           "beforeUrl": "https://github.com/user-attachments/assets/…", "afterUrl": "…" }   // urls optional
 *       ]
 *     }
 *   ],
 *   "rejected": [ { "reason": "로그인 페이지 캡처", "count": 1 } ]        // optional
 * }
 *
 * Media rules (gh --attach): paths inside cwd, no whitespace, images png/jpg/gif/webp, videos mp4/mov/webm.
 * Videos render on their own line so GitHub shows a player. A video-pair renders as an HTML table only when
 * both beforeUrl and afterUrl are present (uploaded through a temporary comment first); otherwise as two
 * own-line videos. Images over 10 MB and videos over 10 MB are refused (free-plan cap).
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
  if (start !== -1 && end !== -1 && end > start) {
    if (body.indexOf(MARKER_START, start + MARKER_START.length) !== -1 || body.indexOf(MARKER_END, end + MARKER_END.length) !== -1) {
      throw new Error("PR body contains more than one verify marker block");
    }
    const prefix = body.slice(0, start).trimEnd();
    const suffixText = body.slice(end + MARKER_END.length).trim();
    return [prefix, block.trim(), suffixText].filter(Boolean).join("\n\n") + "\n";
  }
  if (start !== -1 || end !== -1) throw new Error("PR body contains an incomplete verify marker block");

  // No markers: take over a hand-written `## 완료 조건 검증` section (implement's template) when there is exactly one.
  const headings = [...body.matchAll(/^## 완료 조건 검증\s*$/gm)];
  if (headings.length > 1) throw new Error("PR body contains more than one `## 완료 조건 검증` section");
  if (headings.length === 1) {
    const from = headings[0].index;
    const next = body.slice(from + headings[0][0].length).search(/^## /m);
    const to = next === -1 ? body.length : from + headings[0][0].length + next;
    const prefix = body.slice(0, from).trimEnd();
    const suffixText = body.slice(to).trim();
    return [prefix, block.trim(), suffixText].filter(Boolean).join("\n\n") + "\n";
  }
  const prefix = body.trimEnd();
  return prefix ? `${prefix}\n\n${block}` : block;
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
