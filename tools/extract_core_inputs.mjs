// Phase B extractor: harvest literal compile/parse inputs from the pinned
// vuejs/core test suite into a flat JSON corpus for dual-end differential
// testing. Only statically-decidable literal sources + scalar options are
// collected; everything else is counted as skipped.
import { readFileSync, readdirSync, statSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, dirname, join, relative } from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { parse } = require("@babel/parser");

const CORE_ROOT =
  process.argv[2] ?? "../_refs/vuejs-core/packages";
const OUT = process.argv[3] ?? "batch_inputs.json";

const CALLEE_KIND = {
  compile: "template",
  compileTemplate: "template",
  baseParse: "template",
  compileScript: "sfc",
  parse: null, // depends on package: compiler-sfc => sfc, others => skip AST-only
};

const OPTION_KEYS = new Set([
  "prefixIdentifiers",
  "hoistStatic",
  "cacheHandlers",
  "whitespace",
  "isTS",
  "inline",
  "inlineTemplate",
  "mode",
  "ssr",
  "inSSR",
  "isProd",
  "scoped",
  "slotted",
  "comments",
  "filename",
  "id",
]);

function* walkFiles(dir) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) yield* walkFiles(full);
    else if (entry.endsWith(".spec.ts") || entry.endsWith(".ts")) yield full;
  }
}

function evalStatic(node) {
  if (!node) return undefined;
  switch (node.type) {
    case "StringLiteral":
      return node.value;
    case "NumericLiteral":
    case "BooleanLiteral":
      return node.value;
    case "NullLiteral":
      return null;
    case "ObjectExpression": {
      const out = {};
      for (const prop of node.properties) {
        if (prop.type !== "ObjectProperty") return undefined;
        if (prop.key.type !== "Identifier") return undefined;
        if (!OPTION_KEYS.has(prop.key.name)) continue;
        out[prop.key.name] = evalStatic(prop.value);
        if (out[prop.key.name] === undefined) return undefined;
      }
      return out;
    }
    case "TemplateLiteral":
      return node.expressions.length === 0 ? node.quasis[0].value.cooked : undefined;
    case "TSAsExpression":
    case "TSSatisfiesExpression":
      return evalStatic(node.expression);
    default:
      return undefined;
  }
}

function extractSource(node) {
  if (!node) return undefined;
  if (node.type === "TemplateLiteral" && node.expressions.length === 0) {
    return node.quasis[0].value.cooked;
  }
  if (node.type === "StringLiteral") return node.value;
  if (
    node.type === "TSAsExpression" ||
    node.type === "TSSatisfiesExpression"
  ) {
    return extractSource(node.expression);
  }
  return undefined;
}

function extractFromCall(pkg, node) {
  const name = calleeName(node.callee);
  if (name == null) return null;
  let kind = CALLEE_KIND[name] ?? null;
  if (name === "parse") {
    kind = pkg === "compiler-sfc" ? "sfc" : null;
  }
  // 测试包装器：parseWithXxx / compileWithXxx / makeXxxCompile 等，
  // 一参即模板字面量——统一按包归属分类后走完整管线对拍。
  if (
    !kind &&
    (/^(compileWith|parseWith|transformWith)/.test(name) ||
      /^compile/.test(name))
  ) {
    kind = pkg === "compiler-sfc" ? "sfc" : "template";
  }
  if (!kind) return null;
  const source = extractSource(node.arguments[0]);
  if (source === undefined || source.trim().length === 0) {
    return { skipped: true };
  }
  const options = evalStatic(node.arguments[1]);
  return {
    kind,
    source,
    ...(options && Object.keys(options).length ? { options } : {}),
  };
}

const seen = new Set();
const inputs = [];
let skippedCalls = 0;

function calleeName(callee) {
  if (callee.type === "Identifier") return callee.name;
  if (callee.type === "MemberExpression" && !callee.computed) {
    return callee.property.name;
  }
  return null;
}

for (const pkg of ["compiler-core", "compiler-dom", "compiler-sfc"]) {
  const testsDir = join(CORE_ROOT, pkg, "__tests__");
  let files;
  try {
    files = Array.from(walkFiles(testsDir)).filter((f) => f.includes("__tests__"));
  } catch {
    continue;
  }
  for (const file of files) {
    if (file.includes("testUtils") || file.includes("/__snapshots__/")) continue;
    const code = readFileSync(file, "utf8");
    let ast;
    try {
      ast = parse(code, {
        sourceType: "module",
        plugins: [["typescript", { allowDeclareFields: true }], "jsx"],
      });
    } catch {
      continue;
    }
    const rel = relative(CORE_ROOT, file);
    const stack = [...ast.program.body];
    while (stack.length) {
      const node = stack.pop();
      if (!node || typeof node !== "object") continue;
      if (Array.isArray(node)) {
        stack.push(...node);
        continue;
      }
      if (node.type === "CallExpression") {
        const extracted = extractFromCall(pkg, node);
        if (extracted?.skipped) skippedCalls++;
        else if (extracted) {
          const { kind, source, options } = extracted;
          const key = `${kind}\u0000${source}\u0000${JSON.stringify(options ?? {})}`;
          if (!seen.has(key)) {
            seen.add(key);
            inputs.push({
              id: `${pkg}/${basename(file, ".spec.ts")}_${inputs.length}`,
              from: rel,
              kind,
              source,
              ...(options && Object.keys(options).length ? { options } : {}),
            });
          }
        }
      }
      for (const key of Object.keys(node)) {
        if (key === "loc" || key === "start" || key === "end" || key === "leadingComments" || key === "trailingComments") continue;
        const val = node[key];
        if (val && typeof val === "object") stack.push(val);
      }
    }
  }
}

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(inputs));
console.log(
  `collected ${inputs.length} inputs (${skippedCalls} non-literal calls skipped)`
);
