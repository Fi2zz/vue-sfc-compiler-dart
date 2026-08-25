// Official-side entity decode oracle: compile template, extract rendered string.
import { compileTemplate } from "@vue/compiler-sfc";
const source = process.argv[2];
const r = compileTemplate({ source, filename: "./p.vue", id: "./p.vue" });
if (r.errors.length) { console.log("ERR:" + r.errors[0].message); }
else console.log(r.code.trim().split("\n").pop());
