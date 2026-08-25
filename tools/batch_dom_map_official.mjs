// Decode official compiler-dom FUNCTION-mode maps into canonical segment
// lines for diffing (Phase C pattern, dom corpus). Diff against the output
// of tools/batch_dom_map_dart.dart.
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { compile } from "@vue/compiler-dom";
const inputs = JSON.parse(
  readFileSync(process.argv[2] ?? "batch_dom_inputs.json", "utf8"),
);
const outDir = process.argv[3] ?? "../batch_out/dom_maps_official";
mkdirSync(outDir, { recursive: true });
const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
function decode(mappings) {
  const out = [];
  let gl = 1,
    gc = 0,
    si = 0,
    ol = 0,
    oc = 0,
    ni = 0;
  for (const line of mappings.split(";")) {
    gc = 0;
    if (line !== "") {
      for (const seg of line.split(",")) {
        if (seg === "") continue;
        const vals = [];
        let shift = 0,
          val = 0;
        for (const ch of seg) {
          const d = B64.indexOf(ch);
          const cont = (d & 32) !== 0;
          val += (d & 31) << shift;
          if (cont) {
            shift += 5;
          } else {
            const neg = val & 1;
            val >>= 1;
            vals.push(neg ? -val : val);
            val = 0;
            shift = 0;
          }
        }
        gc += vals[0];
        if (vals.length >= 4) {
          si += vals[1];
          ol += vals[2];
          oc += vals[3];
          const s = [gl, gc, si, ol + 1, oc];
          if (vals.length >= 5) {
            ni += vals[4];
            s.push(ni);
          }
          out.push(s);
        } else out.push([gl, gc]);
      }
    }
    gl++;
  }
  return out;
}
const combos = [
  ["fn", {}],
  ["fn_hoist", { hoistStatic: true }],
];
for (const { id, source } of inputs) {
  for (const [label, options] of combos) {
    let out;
    try {
      const r = compile(source, { sourceMap: true, ...options });
      out = r.map ? JSON.stringify(decode(r.map.mappings)) : "NOMAP";
    } catch (e) {
      out = "THROW";
    }
    writeFileSync(`${outDir}/${id.replaceAll("/", "__")}__${label}.txt`, `${out}\n`);
  }
}
console.log("done");
