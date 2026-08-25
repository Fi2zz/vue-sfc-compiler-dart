// Annotate decoded segments with generated/source context chars for triage.
import { readFileSync } from "node:fs";
import { compileTemplate } from "@vue/compiler-sfc";
const source = process.argv[2];
const r = compileTemplate({ source, filename: "./p.vue", id: "./p.vue", sourceMap: true });
const genLines = r.code.split("\n");
const srcLines = source.split("\n");
const B64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
let gl=1,gc=0,ol=0,oc=0;
for(const line of r.map.mappings.split(';')){gc=0;
  if(line!==''){for(const seg of line.split(',')){if(seg==='')continue;
    const vals=[];let shift=0,val=0;
    for(const ch of seg){const d=B64.indexOf(ch);const cont=(d&32)!==0;val+=(d&31)<<shift;
      if(cont){shift+=5}else{const neg=val&1;val>>=1;vals.push(neg?-val:val);val=0;shift=0}}
    gc+=vals[0];ol+=vals[2];oc+=vals[3];
    const gtxt=(genLines[gl-1]??"").slice(gc,gc+8);
    const stxt=(srcLines[ol]??""===undefined?"":(srcLines[ol]!==undefined?srcLines[ol].slice(oc,oc+8):"<eof>"));
    console.log(`gen(${gl},${gc}) ${JSON.stringify(gtxt).padEnd(12)} -> orig(${ol+1},${oc}) ${JSON.stringify(stxt)}`);
  }}gl++;}
