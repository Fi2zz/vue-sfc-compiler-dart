const filename = "./vue_complex.vue";
const vue_complex = await Bun.file(filename).text();
const outfile = Bun.file("vue_complex_official.md");
const outfile2 = Bun.file("vue_complex_template_official.md");

import { compileScript, parseToSFCDescriptor } from "./compiler.js";

const descriptor = parseToSFCDescriptor(vue_complex, filename);
const script = compileScript(descriptor, filename);
if (script.type == "error") {
  outfile.write(`${script.error}`);
  console.log(script.error);
  console.log("vue-compiler fatal");
} else {
  const code = script.code?.trim();
  let md = "";
  md += "```ts\n";
  md += code;
  md += "\n```";
  outfile.write(md);
  console.log("vue-compiler ok");
}
