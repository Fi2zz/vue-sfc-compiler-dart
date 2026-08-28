// v3: compare samples_style/ (official compileStyle ground truth) with
// samples_style_dart/ (this implementation). Byte-exact, no prettier step.
import { readFile, readdir } from "node:fs/promises";

const officialDir = "samples_style";
const dartDir = "samples_style_dart";
const files = (await readdir(officialDir)).filter((f) => f.endsWith(".md")).sort();
// Error-path goldens embed the absolute repo path of the sample file. Normalize
// it (and any leading absolute path generally) so comparison is machine-independent.
const normalizePath = (text) =>
  text.replaceAll(`${process.cwd()}/`, "").replaceAll(/(?:^|(?<=\n|: ))\/Users\/[^\s:]+\/(vue-sfc-compiler-dart\/)/g, "$1");
let exact = 0;
const diffs = [];
const missing = [];
for (const f of files) {
  const official = normalizePath(await readFile(`${officialDir}/${f}`, "utf8"));
  let dart;
  try {
    dart = normalizePath(await readFile(`${dartDir}/${f}`, "utf8"));
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
