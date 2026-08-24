import { compileScript, parse } from "vue/compiler-sfc";
import { mkdir, writeFile, readFile } from "node:fs/promises";
const samples = JSON.parse(await readFile("samples.json", "utf8"));
const outDir = process.argv[2] || "samples_official_check";
await mkdir(outDir, { recursive: true });
for (const { name, sfc } of samples) {
  const filename = `./${name}.vue`;
  const { descriptor } = parse(sfc, { filename });
  let md = `# ${name}\n\n`;
  try {
    const script = compileScript(descriptor, { id: filename, hoistStatic: false });
    const code = script.content.trim();
    if (code) md += "```\n" + code + "\n```\n";
  } catch (error) {
    // 与 Dart 侧 SfcCompileError.toString 的格式保持一致（历史 ground truth 均带此前缀）。
    md += "Vue Compile Error: " + String(error && error.message ? error.message : error) + "\n";
  }
  await writeFile(`${outDir}/${name}.md`, md);
}
console.log("done", samples.length);
