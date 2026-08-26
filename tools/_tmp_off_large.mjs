import { readFileSync } from "node:fs";
import { parse, compileScript, compileTemplate, compileStyle } from "@vue/compiler-sfc";
const files = [10, 50].map(m => readFileSync(`bench/corpus/large_${m}.vue`, "utf8"));
function compileOne(src, name) {
  const { descriptor } = parse(src, { filename: `./${name}.vue` });
  let bindings;
  if (descriptor.scriptSetup || descriptor.script)
    bindings = compileScript(descriptor, { id: "data-v-x" }).bindings;
  if (descriptor.template)
    compileTemplate({ source: descriptor.template.content, filename: `./${name}.vue`, id: "data-v-x", bindingMetadata: bindings });
  for (const s of descriptor.styles)
    compileStyle({ source: s.content, filename: `./${name}.vue`, id: "data-v-x", scoped: s.scoped });
}
for (let w = 0; w < 20; w++) files.forEach((s, i) => compileOne(s, `w${i}`));
const samples = [];
for (let r = 0; r < 150; r++) {
  const t0 = process.hrtime.bigint();
  files.forEach((s, i) => compileOne(s, `r${i}`));
  samples.push(Number(process.hrtime.bigint() - t0) / 1000);
}
samples.sort((a, b) => a - b);
console.log("official large p50=" + (samples[75] / 1000).toFixed(2) + "ms");
