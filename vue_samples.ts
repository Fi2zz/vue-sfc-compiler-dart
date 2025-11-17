import { compileScript, parse } from "vue/compiler-sfc";
import { mkdir } from "node:fs/promises";

import {} from "./compiler.js";
import samples from "./samples.json" with { type: "json" };
type Compiled = {
  name: string;
  sfc: string;
  code?: string;
  warnings: string[];
  error?: string;
};
const compiled: Compiled[] = [];
for (const { name, sfc } of samples) {
  const filename = `./${name}.vue`;
  const { descriptor } = parse(sfc, { filename });
  const warnings: string[] = [];
  const origWarn = console.warn;
  console.warn = (...args: any[]) => {
    const raw = args
      .map((a) => (typeof a === "string" ? a : String(a)))
      .join(" ");
    if (raw.includes("[@vue/compiler-sfc]")) {
      const cleaned = raw.replace(/\x1B\[[0-9;]*m/g, "").trim();
      warnings.push(cleaned);
    }
    return origWarn.apply(console, args as any);
  };
  try {
    const script = compileScript(descriptor, {
      id: filename,
      hoistStatic: false,
    });
    const code = script.content.trim();
    // tsOutput += `// ==== ${name} ====\n` + code + "\n\n";
    compiled.push({ name, sfc, code, warnings });
  } catch (e: any) {
    const errMsg = e?.message ? String(e.message).trim() : String(e);
    compiled.push({ name, sfc, warnings, error: errMsg });
    console.log(`err ${errMsg}`);
  } finally {
    console.warn = origWarn;
  }
}
await mkdir("samples_vanilla", { recursive: true });
for (const { name, sfc, code, warnings, error } of compiled) {
  let md = `# ${name}\n\n`;
  md += "示例：\n\n";
  md += "```vue\n" + sfc + "\n```\n\n";
  if (code) {
    md += "编译输出：\n\n";
    md += "```ts\n" + code + "\n```\n\n";
  }
  if (warnings && warnings.length) {
    md += "警告：\n\n";
    for (const w of warnings) md += "- " + w + "\n";
    md += "\n";
  }
  if (error) {
    md += "错误：\n\n";
    md += "``\n" + error + "\n``\n\n";
  }
  await Bun.file(`samples_vanilla/${name}.md`).write(md);
}
console.log("all done");
