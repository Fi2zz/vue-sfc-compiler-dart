import { compileScript, parse } from "vue/compiler-sfc";
import { mkdir } from "node:fs/promises";
import samples from "./samples.json" with { type: "json" };
type Compiled = {
  name: string;
  code?: string;
  error?: string;
};
const compiled: Compiled[] = [];
for (const { name, sfc } of samples) {
  const filename = `./${name}.vue`;
  const { descriptor } = parse(sfc, { filename });
  try {
    const script = compileScript(descriptor, {
      id: filename,
      hoistStatic: false,
    });
    const code = script.content.trim();
    compiled.push({ name, code });
  } catch (error) {
    compiled.push({
      name,
      error: (error as unknown as Error)!.message ?? `${error}`,
    });
  } finally {
  }
}
await mkdir("samples", { recursive: true });
for (const { name, code, error } of compiled) {
  let md = `# ${name}\n\n`;
  if (code) md += "```\n" + code + "\n```\n\n";
  if (error) md += "Vue Compile Error: " + error;
  await Bun.file(`samples/${name}.md`).write(md);
}
