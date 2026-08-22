// Generate official compileTemplate outputs for template samples.
import { parse, compileTemplate } from "@vue/compiler-sfc";
import { mkdir, writeFile, readFile } from "node:fs/promises";
const samples = JSON.parse(await readFile("samples_tmpl.json", "utf8"));
const outDir = process.argv[2] || "samples_tmpl";
await mkdir(outDir, { recursive: true });
for (const { name, sfc } of samples) {
  const filename = `./${name}.vue`;
  const { descriptor, errors } = parse(sfc, { filename });
  let md = `# ${name}\n\n`;
  if (errors.length) {
    md += "Vue Compile Error: " + String(errors[0].message ?? errors[0]) + "\n";
  } else {
    try {
      const result = compileTemplate({
        source: descriptor.template.content,
        filename,
        id: filename,
      });
      md += "```\n" + result.code.trim() + "\n```\n";
      if (result.errors.length) md += "ERRORS: " + result.errors.join("; ") + "\n";
    } catch (error) {
      md += "Vue Compile Error: " + String(error && error.message ? error.message : error) + "\n";
    }
  }
  await writeFile(`${outDir}/${name}.md`, md);
}
console.log("done", samples.length);
