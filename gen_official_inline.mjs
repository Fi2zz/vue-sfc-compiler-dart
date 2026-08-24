// Generate official compileScript(inlineTemplate:true) outputs.
// Mirrors the vite-plugin-vue build flow: script compiled with default
// hoistStatic and the template inlined as the setup return value.
import { parse, compileScript } from "@vue/compiler-sfc";
import { mkdir, writeFile, readFile } from "node:fs/promises";
const samples = JSON.parse(await readFile("samples_inline.json", "utf8"));
const outDir = process.argv[2] || "samples_inline";
await mkdir(outDir, { recursive: true });
for (const { name, sfc } of samples) {
  const filename = `./${name}.vue`;
  const { descriptor } = parse(sfc, { filename });
  let md = `# ${name}\n\n`;
  try {
    const result = compileScript(descriptor, { id: filename, inlineTemplate: true });
    md += "```\n" + result.content.trim() + "\n```\n";
    if (result.bindings && Object.keys(result.bindings).length) {
      md += "\nBINDINGS: " + JSON.stringify(result.bindings) + "\n";
    }
  } catch (error) {
    md += "Vue Compile Error: " + String(error && error.message ? error.message : error) + "\n";
  }
  await writeFile(`${outDir}/${name}.md`, md);
}
console.log("done", samples.length);
