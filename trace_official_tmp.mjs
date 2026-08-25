// Trace official codegen: patch SourceMapGenerator.addMapping via map object.
import { compileTemplate } from "@vue/compiler-sfc";
const source = '<div v-for="({ a, b }, key, index) of a.b" />';
const r = compileTemplate({ source, filename: "./p.vue", id: "./p.vue", sourceMap: true });
console.log(r.code);
const json = r.map;
console.log("sources:", json.sources);
const B64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function decode(mappings){
  const out=[];let gl=1,gc=0,si=0,ol=0,oc=0;
  for(const line of mappings.split(';')){gc=0;
    if(line!==''){for(const seg of line.split(',')){if(seg==='')continue;
      const vals=[];let shift=0,val=0;
      for(const ch of seg){const d=B64.indexOf(ch);const cont=(d&32)!==0;val+=(d&31)<<shift;
        if(cont){shift+=5}else{const neg=val&1;val>>=1;vals.push(neg?-val:val);val=0;shift=0}}
      gc+=vals[0];si+=vals[1];ol+=vals[2];oc+=vals[3];
      out.push([gl,gc,ol+1,oc]);
    }}gl++;}
  return out;
}
for (const [gl,gc,ol,oc] of decode(json.mappings)) {
  console.log(`gen(${gl},${gc}) -> orig(${ol},${oc})`);
}
