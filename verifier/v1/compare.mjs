// Baseline verifier: compare official samples/ vs dart samples_dart/.
// Levels per sample: EXACT (byte equal), NORMALIZED (equal after prettier
// babel formatting of the fenced code), MATCH_ERROR (both error text equal),
// DIFF (otherwise). Prints JSON summary + list of DIFF sample names.
import { readFile, readdir } from "node:fs/promises";
import prettier from "prettier";

const [A, B] = ["samples", "samples_dart"];
const fence = /```(?:\w+)?\n([\s\S]*?)```/;
const extract = (md) => md.match(fence)?.[1]?.trim() ?? null;

async function norm(code) {
  try {
    return (await prettier.format(code, { parser: "babel" })).trim();
  } catch {
    return `__UNPARSEABLE__${code}`;
  }
}

const names = (await readdir(A)).filter((f) => f.endsWith(".md")).sort();
const summary = { EXACT: 0, NORMALIZED: 0, MATCH_ERROR: 0, DIFF: 0, MISSING: 0 };
const diffs = [];
for (const f of names) {
  const mdA = await readFile(`${A}/${f}`, "utf8");
  let mdB = null;
  try { mdB = await readFile(`${B}/${f}`, "utf8"); } catch { summary.MISSING++; diffs.push(f); continue; }
  if (mdA === mdB) { summary.EXACT++; continue; }
  const ca = extract(mdA), cb = extract(mdB);
  if (ca === null || cb === null) {
    if (mdA.trim() === mdB.trim()) summary.MATCH_ERROR++; else { summary.DIFF++; diffs.push(f); }
    continue;
  }
  if ((await norm(ca)) === (await norm(cb))) summary.NORMALIZED++;
  else { summary.DIFF++; diffs.push(f); }
}
console.log(JSON.stringify({ total: names.length, ...summary }, null, 2));
console.log("DIFF_FILES:"); diffs.forEach((d) => console.log(d));
process.exit(summary.DIFF || summary.MISSING ? 1 : 0);
