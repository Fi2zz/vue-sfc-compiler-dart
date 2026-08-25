// compiler-dom batch runner (official side): compile every input with
// @vue/compiler-dom compile() under DEFAULT options, mirroring
// tools/batch_official.mjs. Errors surface as THROW (official defaultOnError).
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { compile } from "@vue/compiler-dom";

const IN = process.argv[2] ?? "batch_dom_inputs.json";
const OUT = process.argv[3] ?? "../batch_out/dom_official";
const inputs = JSON.parse(readFileSync(IN, "utf8"));
mkdirSync(OUT, { recursive: true });

for (const { id, source } of inputs) {
  let out = "";
  try {
    const result = compile(source);
    out = result.code.trim() + "\n";
  } catch (e) {
    out = "THROW: " + String(e && e.message ? e.message : e) + "\n";
  }
  writeFileSync(`${OUT}/${id.replaceAll("/", "__")}.txt`, out);
}
console.log("done", inputs.length);
