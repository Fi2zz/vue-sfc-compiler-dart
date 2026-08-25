import { compileTemplate } from "@vue/compiler-sfc";
const source = process.argv[2];
const r = compileTemplate({ source, filename: "./p.vue", id: "./p.vue", sourceMap: true });
console.log(r.code);
console.log('names:', r.map.names ?? []);
const B64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
let gl=1,gc=0,si=0,ol=0,oc=0,ni=0;
for(const line of r.map.mappings.split(';')){gc=0;
  if(line!==''){for(const seg of line.split(',')){if(seg==='')continue;
    const vals=[];let shift=0,val=0;
    for(const ch of seg){const d=B64.indexOf(ch);const cont=(d&32)!==0;val+=(d&31)<<shift;
      if(cont){shift+=5}else{const neg=val&1;val>>=1;vals.push(neg?-val:val);val=0;shift=0}}
    gc+=vals[0];
    if(vals.length>=4){si+=vals[1];ol+=vals[2];oc+=vals[3];let n='';if(vals.length>=5){ni+=vals[4];n=(r.map.names??[])[ni]??'?'}console.log(`gen(${gl},${gc}) orig(${ol+1},${oc}) name=${JSON.stringify(n)}`)}else console.log(`gen(${gl},${gc}) nosrc`);
  }}gl++;}
