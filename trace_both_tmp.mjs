import { compileTemplate } from "@vue/compiler-sfc";
import { readFileSync } from "node:fs";
const source = readFileSync(process.argv[2], "utf8");
const r = compileTemplate({ source, filename: "./p.vue", id: "./p.vue", sourceMap: true });
console.log(r.code);
console.log('errors:', r.errors.length ? r.errors.map(e=>e.message) : 'none');
const B64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
let gl=1,gc=0,ol=0,oc=0;
for(const line of r.map.mappings.split(';')){gc=0;
  if(line!==''){for(const seg of line.split(',')){if(seg==='')continue;
    const vals=[];let shift=0,val=0;
    for(const ch of seg){const d=B64.indexOf(ch);const cont=(d&32)!==0;val+=(d&31)<<shift;
      if(cont){shift+=5}else{const neg=val&1;val>>=1;vals.push(neg?-val:val);val=0;shift=0}}
    gc+=vals[0];ol+=vals[2];oc+=vals[3];
    console.log(`gen(${gl},${gc}) -> orig(${ol+1},${oc})`);
  }}gl++;}
