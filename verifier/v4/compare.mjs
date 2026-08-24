// v4: compare samples_inline/ (official compileScript inlineTemplate ground truth) with
// samples_inline_dart/ (this implementation). Byte-exact, no prettier step.
import { readFile, readdir } from "node:fs/promises";

const officialDir = "samples_inline";
const dartDir = "samples_inline_dart";
const files = (await readdir(officialDir)).filter((f) => f.endsWith(".md")).sort();
let exact = 0;
const diffs = [];
const missing = [];
for (const f of files) {
  const official = await readFile(`${officialDir}/${f}`, "utf8");
  let dart;
  try {
    dart = await readFile(`${dartDir}/${f}`, "utf8");
  } catch {
    missing.push(f);
    continue;
  }
  if (dart === official) exact++;
  else diffs.push(f);
}
console.log(`EXACT ${exact}/${files.length}`);
for (const f of diffs) console.log(`DIFF ${f}`);
for (const f of missing) console.log(`MISSING ${f}`);
process.exit(diffs.length || missing.length ? 1 : 0);
