// Decode official template maps into canonical segment lines for diffing.
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { compileTemplate } from "@vue/compiler-sfc";
const inputs = JSON.parse(readFileSync(process.argv[2] ?? "batch_inputs.json", "utf8"));
const outDir = process.argv[3] ?? "../batch_out/maps_official";
mkdirSync(outDir, { recursive: true });
const B64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function decode(mappings){
  const out=[];let gl=1,gc=0,si=0,ol=0,oc=0,ni=0;
  for(const line of mappings.split(';')){
    gc=0;
    if(line!==''){
      for(const seg of line.split(',')){
        if(seg==='')continue;
        const vals=[];let shift=0,val=0;
        for(const ch of seg){
          const d=B64.indexOf(ch);const cont=(d&32)!==0;val+=(d&31)<<shift;
          if(cont){shift+=5}else{const neg=val&1;val>>=1;vals.push(neg?-val:val);val=0;shift=0}
        }
        gc+=vals[0];
        if(vals.length>=4){si+=vals[1];ol+=vals[2];oc+=vals[3];const s=[gl,gc,si,ol+1,oc];if(vals.length>=5){ni+=vals[4];s.push(ni)}out.push(s)}else out.push([gl,gc]);
      }
    }
    gl++;
  }
  return out;
}
for (const { id, kind, source } of inputs) {
  if (kind !== 'template') continue;
  let out;
  try {
    const r = compileTemplate({ source, filename: `./${id}.vue`, id: `./${id}.vue`, sourceMap: true });
    out = r.map ? JSON.stringify(decode(r.map.mappings)) : 'NOMAP';
  } catch (e) { out = 'THROW'; }
  writeFileSync(`${outDir}/${id.replaceAll('/', '__')}.txt`, out + '\n');
}
console.log('done');
