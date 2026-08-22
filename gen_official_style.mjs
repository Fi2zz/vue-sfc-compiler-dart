// Generate official compileStyle outputs for style samples.
import { compileStyle } from "@vue/compiler-sfc";
import { mkdir, writeFile, readFile } from "node:fs/promises";
const samples = JSON.parse(await readFile("samples_style.json", "utf8"));
const outDir = process.argv[2] || "samples_style";
await mkdir(outDir, { recursive: true });
for (const { name, source, options } of samples) {
  const filename = `./${name}.vue`;
  let md = `# ${name}\n\n`;
  const result = compileStyle({
    source,
    filename,
    id: filename,
    scoped: options?.scoped ?? false,
    trim: options?.trim ?? true,
    isProd: options?.isProd ?? false,
  });
  md += "```\n" + result.code + "\n```\n";
  if (result.errors.length) {
    md += "ERRORS: " + result.errors.map(String).join("; ") + "\n";
  }
  await writeFile(`${outDir}/${name}.md`, md);
}
console.log("done", samples.length);
