#!/usr/bin/env node
// 스크린샷 위에 번호 배지와 화살표를 그려 PNG로 저장한다. 사용법은 인자 없이 실행하면 나온다.
// Chrome 대신 ImageMagick을 쓰는 이유는 references/background.md에 있다.

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const [input, specPath, output] = process.argv.slice(2);
if (!input || !specPath || !output) {
  console.error(`사용법: node annotate.mjs <입력 이미지> <표시.json> <출력.png>

표시.json — target은 화살촉이 닿을 지점, from은 번호 배지의 중심
  { "marks": [ { "n": 1, "target": [600, 470], "from": [700, 330] } ] }

좌표는 입력 이미지의 픽셀 기준이다. 브라우저 DOM 좌표는 devicePixelRatio를 곱한다.`);
  process.exit(1);
}

function which(name) {
  try {
    return execFileSync("which", [name], { encoding: "utf8" }).trim() || null;
  } catch {
    return null;
  }
}

// IM7은 magick, IM6은 convert. 샌드박스에서 PATH가 줄어들 수 있어 Homebrew 경로도 본다.
const magick =
  which("magick") ??
  ["/opt/homebrew/bin/magick", "/usr/local/bin/magick"].find(existsSync) ??
  which("convert");
if (!magick) {
  console.error("ImageMagick을 찾지 못했다. 표시 없이 원본 이미지를 쓴다.");
  process.exit(2);
}

// IM7은 `magick identify`, IM6은 convert 옆의 identify.
const im6 = /convert$/.test(magick);
const [idBin, idArgs] = im6 ? [magick.replace(/convert$/, "identify"), []] : [magick, ["identify"]];
const size = (file) =>
  execFileSync(idBin, [...idArgs, "-format", "%w %h", `${file}[0]`], { encoding: "utf8" })
    .trim()
    .split(" ")
    .map(Number);

let width, height;
try {
  [width, height] = size(input);
} catch {
  console.error(`이미지를 읽지 못했다: ${input}`);
  process.exit(1);
}

const { marks } = JSON.parse(readFileSync(specPath, "utf8"));
for (const m of marks) {
  for (const [x, y] of [m.target, m.from]) {
    if (x < 0 || y < 0 || x > width || y > height) {
      console.error(`${m.n}번 좌표가 이미지(${width}x${height}) 밖에 있다: ${x},${y}`);
      process.exit(1);
    }
  }
}

const font = [
  "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
  "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
].find(existsSync);

// 1400px 폭(노트북 1배 캡처)을 1배로 잡고, 레티나 캡처는 3배까지 키운다.
const s = Math.min(3, Math.max(1, width / 1400));
const r = 15 * s;
const color = "#E8336D";
const halo = "rgba(255,255,255,0.85)";
const f = (v) => v.toFixed(1);
const offset = (v) => (v < 0 ? `${f(v)}` : `+${f(v)}`);

const args = [`${input}[0]`]; // 첫 프레임만 쓴다(GIF)
for (const { n, target: [tx, ty], from: [fx, fy] } of marks) {
  const len = Math.hypot(tx - fx, ty - fy);
  const ux = (tx - fx) / len;
  const uy = (ty - fy) / len;
  // 선은 배지 테두리에서 화살촉 뿌리까지 긋는다.
  const head = 12 * s;
  const sx = fx + ux * (r + 2 * s);
  const sy = fy + uy * (r + 2 * s);
  const ex = tx - ux * head;
  const ey = ty - uy * head;
  const px = -uy * head * 0.55;
  const py = ux * head * 0.55;
  const line = `line ${f(sx)},${f(sy)} ${f(ex)},${f(ey)}`;
  const tip = `polygon ${f(tx)},${f(ty)} ${f(ex + px)},${f(ey + py)} ${f(ex - px)},${f(ey - py)}`;

  args.push(
    // 어두운 배경에서도 보이도록 흰 테두리를 먼저 깐다.
    "-stroke", halo, "-strokewidth", f(6 * s), "-fill", "none", "-draw", line,
    "-stroke", halo, "-strokewidth", f(3 * s), "-fill", halo, "-draw", tip,
    "-stroke", color, "-strokewidth", f(3 * s), "-draw", line,
    "-stroke", "none", "-fill", color, "-draw", tip,
    "-stroke", "white", "-strokewidth", f(2.5 * s), "-fill", color,
    "-draw", `circle ${f(fx)},${f(fy)} ${f(fx + r)},${f(fy)}`,
    "-stroke", "none", "-fill", "white", "-gravity", "Center", "-pointsize", f(17 * s),
    ...(font ? ["-font", font] : []),
    "-annotate", `${offset(fx - width / 2)}${offset(fy - height / 2)}`, String(n),
    "-gravity", "NorthWest",
  );
}
const outAbs = resolve(output);
args.push(`PNG:${outAbs}`);

execFileSync(magick, args, { stdio: ["ignore", "ignore", "inherit"], timeout: 60_000 });

const [ow, oh] = size(outAbs);
if (ow !== width || oh !== height) {
  console.error(`출력 크기(${ow}x${oh})가 입력(${width}x${height})과 다르다.`);
  process.exit(1);
}
console.log(`${outAbs} (${width}x${height}, 표시 ${marks.length}개)`);
