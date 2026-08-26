import { readFileSync } from "node:fs";
import { parse as parseSFC } from "@vue/compiler-sfc";
import { baseParse, parserOptions } from "@vue/compiler-dom";
console.log = () => {}; console.warn = () => {};
const tpl = parseSFC(readFileSync("bench/corpus/large_50.vue","utf8"),{}).descriptor.template.content;
const N = 60;
const t = (f) => { for(let i=0;i<5;i++)f(); const t0=performance.now(); for(let i=0;i<N;i++)f(); return Math.round((performance.now()-t0)*1000/N); };
const withPrefix = {...parserOptions, prefixIdentifiers:true, hoistStatic:true, cacheHandlers:true, mode:"module"};
// interleaved x3
for (let i=0;i<3;i++) {
  process.stdout.write(`plain=${t(()=>baseParse(tpl, parserOptions))} prefix=${t(()=>baseParse(tpl, withPrefix))}\n`);
}
