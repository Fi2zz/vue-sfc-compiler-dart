import { readFileSync } from "node:fs";
import { parse, compileScript, compileTemplate } from "@vue/compiler-sfc";
const sfc = readFileSync(process.argv[2], "utf8").replace(/^<script setup>/, "<script setup>").trim();
const { descriptor } = parse(sfc, { filename: "./x.vue" });
let bindingMetadata;
if (descriptor.scriptSetup || descriptor.script)
  bindingMetadata = compileScript(descriptor, { id: "./x.vue" }).bindings;
const r = compileTemplate({
  source: descriptor.template.content.trim(),
  filename: "./x.vue", id: "./x.vue",
  compilerOptions: bindingMetadata ? { bindingMetadata } : {},
});
console.log(r.code);
