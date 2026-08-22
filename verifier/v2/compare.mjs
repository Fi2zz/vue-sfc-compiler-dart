// v2: compare samples_tmpl/ (official compileTemplate ground truth) with
// samples_tmpl_dart/ (this implementation). Byte-exact comparison — unlike
// v1, no prettier step: compileTemplate output is compared as generated.
import { readFile, readdir } from "node:fs/promises";

const officialDir = "samples_tmpl";
const dartDir = "samples_tmpl_dart";
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
