// Phase B official-side batch runner: compile every input with the installed
// @vue/compiler-* packages and write per-case output files.
// Both sides run with DEFAULTS (extracted options ignored) so that any diff
// is a real implementation divergence rather than an options-mapping artifact.
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import {
  parse,
  compileScript,
  compileTemplate,
} from "@vue/compiler-sfc";

const IN = process.argv[2] ?? "batch_inputs.json";
const OUT = process.argv[3] ?? "../batch_out/official";
const inputs = JSON.parse(readFileSync(IN, "utf8"));
mkdirSync(OUT, { recursive: true });

for (const { id, kind, source } of inputs) {
  let out = "";
  try {
    if (kind === "sfc") {
      const filename = `./${id}.vue`;
      const { descriptor, errors } = parse(source, { filename });
      if (errors.length) {
        out = "PARSE_ERROR: " + String(errors[0].message ?? errors[0]) + "\n";
      } else if (!descriptor.scriptSetup && !descriptor.script) {
        out = "NO_SCRIPT\n";
      } else {
        const result = compileScript(descriptor, { id: filename });
        out = result.content.trim() + "\n";
        const bindings = result.bindings ?? {};
        delete bindings.__isScriptSetup;
        if (Object.keys(bindings).length) {
          out += "\nBINDINGS: " + JSON.stringify(bindings) + "\n";
        }
      }
    } else {
      const filename = `./${id}.vue`;
      const result = compileTemplate({
        source,
        filename,
        id: filename,
      });
      out = result.code.trim() + "\n";
      if (result.errors.length) {
        out +=
          "\nERRORS: " +
          result.errors.map((e) => String(e.message ?? e)).join("; ") +
          "\n";
      }
    }
  } catch (e) {
    out = "THROW: " + String(e && e.message ? e.message : e) + "\n";
  }
  writeFileSync(`${OUT}/${id.replaceAll('/', '__')}.txt`, out);
}
console.log("done", inputs.length);
