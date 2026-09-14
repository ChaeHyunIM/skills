import assert from "node:assert/strict";
import { test } from "node:test";
import { renderBlock, replaceBlock, MARKER_START, MARKER_END } from "../../verify/scripts/evidence-block.mjs";

const sha = "a".repeat(40);
const result = {
  target: { commit: sha, url: `https://github.com/o/r/commit/${sha}` },
  env: "local fixture",
  items: [{ text: "이름 변경이 유지된다", status: "충족", detail: "reopen test passed" }],
};
const block = renderBlock(result);

test("marked replacement preserves human text and whitespace byte for byte", () => {
  const prefix = "Fixes YOU-1  \r\n\r\nHuman text\t\n\n\n";
  const suffix = "\n\n\t## Notes\nKeep trailing spaces  \n\n";
  const old = `${MARKER_START}\n## 완료 조건 검증\n\nold\n${MARKER_END}`;
  assert.equal(replaceBlock(prefix + old + suffix, block), prefix + block.trimEnd() + suffix);
});

test("legacy record preserves the surrounding sections", () => {
  const prefix = "Fixes YOU-1\n\nHuman prose  \n\n";
  const suffix = "## Review notes\n  Keep this exactly\n\n";
  const updated = replaceBlock(prefix + "## 완료 조건 검증\n\nold\n\n" + suffix, block);
  assert.ok(updated.startsWith(prefix));
  assert.ok(updated.endsWith(suffix));
  assert.equal((updated.match(/^## 완료 조건 검증$/gm) ?? []).length, 1);
});

test("append does not trim an existing body", () => {
  const body = "Fixes YOU-1\nHuman text  \n\n\t";
  assert.ok(replaceBlock(body, block).startsWith(body));
});

test("duplicate or incomplete records are rejected", () => {
  for (const body of [block + block, MARKER_START, MARKER_END + MARKER_START, block + "\n## 완료 조건 검증\nold"]) {
    assert.throws(() => replaceBlock(body, block));
  }
});

test("mismatched target or unsupported verdict is rejected", () => {
  assert.throws(() => renderBlock({ ...result, target: { commit: "not-a-sha" } }));
  assert.throws(() => renderBlock({ ...result, target: { commit: sha, url: "https://github.com/o/r/commit/bbbbbbb" } }));
  assert.throws(() => renderBlock({ ...result, items: [{ ...result.items[0], status: "probably" }] }));
});

test("unverified evidence stays unchecked and keeps its actual reason", () => {
  const rendered = renderBlock({ ...result, items: [{ ...result.items[0], status: "미검증", detail: "device unavailable" }] });
  assert.ok(rendered.includes("- [ ] 이름 변경이 유지된다 — 미검증"));
  assert.ok(rendered.includes("이유: device unavailable"));
});
