// Dump official template AST in a canonical text format for comparison.
import { parse } from "@vue/compiler-dom";
import { readFile } from "node:fs/promises";

const samples = JSON.parse(await readFile("samples_tmpl.json", "utf8"));
const name = process.argv[2];
const s = samples.find((x) => x.name === name);
const m = s.sfc.match(/<template>([\s\S]*)<\/template>/);
const source = m[1];
const root = parse(source);
const enc = (t) => JSON.stringify(t);
const lines = [];
function loc(n) { return `@${n.loc.start.offset}-${n.loc.end.offset}`; }
function prop(p) {
  if (p.type === 6) {
    return `ATTR ${p.name} ${p.value ? enc(p.value.content) : "noval"} ${loc(p)}`;
  }
  const arg = p.arg ? `${p.arg.content}${p.arg.isStatic ? ":s" : ":d"}` : "-";
  const exp = p.exp ? p.exp.content : "-";
  const mods = p.modifiers.map((m) => m.content).join(",");
  return `DIR ${p.name} raw=${p.rawName} arg=${arg} exp=${enc(exp)} mods=[${mods}] ${loc(p)}`;
}
function walk(n, d) {
  const pad = "  ".repeat(d);
  if (n.type === 1) {
    lines.push(`${pad}EL ${n.tag} ns=${n.ns} tagType=${n.tagType} self=${n.isSelfClosing ? 1 : 0} ${loc(n)}`);
    for (const p of n.props) lines.push(`${pad}  ${prop(p)}`);
    for (const c of n.children) walk(c, d + 1);
  } else if (n.type === 2) {
    lines.push(`${pad}TEXT ${enc(n.content)} ${loc(n)}`);
  } else if (n.type === 3) {
    lines.push(`${pad}COMMENT ${enc(n.content)} ${loc(n)}`);
  } else if (n.type === 5) {
    lines.push(`${pad}INTERP ${enc(n.content.content)} ${loc(n)} exp@${n.content.loc.start.offset}-${n.content.loc.end.offset}`);
  }
}
for (const c of root.children) walk(c, 0);
console.log(lines.join("\n"));
