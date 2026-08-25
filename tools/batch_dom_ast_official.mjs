// Canonical-AST differential dump (official side): parse() each input with
// compiler-dom and serialize a whitelisted, fixed-key-order view of the AST.
// Diff against the output of tools/batch_dom_ast_dart.dart. Serialization
// contract (both sides must match exactly):
//   loc  -> {s:[off,line,col], e:[off,line,col], src}
//   ROOT type,source,children / ELEMENT type,tag,ns,tagType,
//     isSelfClosing(only when true),props,children
//   TEXT/COMMENT/INTERPOLATION type,content (3.5 renamed interp exp->content)
//   SIMPLE_EXPRESSION type,content,isStatic,constType
//   ATTRIBUTE type,name,nameLoc,value(Text|null)
//   DIRECTIVE type,name,rawName,exp?,arg?,modifiers[]
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { parse } from "@vue/compiler-dom";

const inputs = JSON.parse(readFileSync(process.argv[2], "utf8"));
const outDir = process.argv[3];
mkdirSync(outDir, { recursive: true });

function L(loc) {
  return {
    s: [loc.start.offset, loc.start.line, loc.start.column],
    e: [loc.end.offset, loc.end.line, loc.end.column],
    src: loc.source,
  };
}
function ser(n) {
  const o = { type: n.type };
  switch (n.type) {
    case 0:
      o.source = n.source;
      o.children = n.children.map(ser);
      break;
    case 1:
      o.tag = n.tag;
      o.ns = n.ns;
      o.tagType = n.tagType;
      if (n.isSelfClosing) o.isSelfClosing = true;
      o.props = n.props.map(ser);
      o.children = n.children.map(ser);
      break;
    case 2:
    case 3:
      o.content = n.content;
      break;
    case 4:
      o.content = n.content;
      o.isStatic = !!n.isStatic;
      o.constType = n.constType ?? 0;
      break;
    case 5:
      o.content = ser(n.content);
      break;
    case 6:
      o.name = n.name;
      o.nameLoc = L(n.nameLoc);
      o.value = n.value ? ser(n.value) : null;
      break;
    case 7:
      o.name = n.name;
      o.rawName = n.rawName ?? null;
      if (n.exp) o.exp = ser(n.exp);
      if (n.arg) o.arg = ser(n.arg);
      o.modifiers = n.modifiers.map(ser);
      break;
    default:
      throw new Error(`unexpected node type ${n.type} in parse output`);
  }
  o.loc = L(n.loc);
  return o;
}
for (const { id, source } of inputs) {
  let out;
  try {
    out = JSON.stringify(ser(parse(source)));
  } catch (e) {
    out = "THROW";
  }
  writeFileSync(`${outDir}/${id.replaceAll("/", "__")}.txt`, `${out}\n`);
}
console.log("done");
