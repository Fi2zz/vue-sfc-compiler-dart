import { compileScript, parse } from "vue/compiler-sfc";
const filename = "./vue_complex.vue";
const vue_complex = await Bun.file(filename).text();
const outfile = Bun.file("vue_complex_official.md");
const { descriptor } = parse(vue_complex, {
  ignoreEmpty: true,
});
try {
  const script = compileScript(descriptor, {
    id: filename,
    hoistStatic: false,
  });
  const code = script.content.trim();
  let md = "";
  md += "```ts\n";
  md += code;
  md += "\n```";
  outfile.write(md);
} catch (error) {
} finally {
}
