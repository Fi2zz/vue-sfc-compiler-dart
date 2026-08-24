// Phase B diff reporter: byte-compare official vs Dart batch outputs.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const [officialDir, dartDir] = process.argv.slice(2);
const files = readdirSync(officialDir).sort();
let same = 0;
const diffs = [];
for (const f of files) {
  let dartPath = join(dartDir, f);
  try {
    statSync(dartPath);
  } catch {
    diffs.push([f, "MISSING"]);
    continue;
  }
  const a = readFileSync(join(officialDir, f), "utf8");
  const b = readFileSync(dartPath, "utf8");
  if (a === b) same++;
  else diffs.push([f, "DIFF"]);
}
console.log(`SAME ${same}/${files.length}`);
for (const [f, tag] of diffs.slice(0, 50)) console.log(`${tag} ${f}`);
if (diffs.length > 50) console.log(`... and ${diffs.length - 50} more`);
