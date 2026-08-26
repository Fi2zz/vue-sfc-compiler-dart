// Official-side template sub-stage probe: baseParse / transform / generate
// on the same large_50 template as tools/_tmpl_split_probe.dart.
// Mirrors compiler-sfc compileTemplate -> compiler-dom compile():
// mode=module, prefixIdentifiers=true, hoistStatic, cacheHandlers.
import { readFileSync } from "node:fs";
import { parse as parseSFC } from "@vue/compiler-sfc";
import {
  baseParse,
  parserOptions,
  transform,
  generate,
  getBaseTransformPreset,
  DOMNodeTransforms,
  DOMDirectiveTransforms,
  compile,
} from "@vue/compiler-dom";

console.log = () => {};
console.warn = () => {};
const say = (l) => process.stdout.write(`${l}\n`);

const src = readFileSync("bench/corpus/large_50.vue", "utf8");
const tpl = parseSFC(src, { filename: "large_50.vue" }).descriptor.template.content;

const [presetNodes, presetDirectives] = getBaseTransformPreset(true);
const sharedOptions = {
  ...parserOptions,
  prefixIdentifiers: true,
  hoistStatic: true,
  cacheHandlers: true,
  mode: "module",
};
const makeTransformOptions = () => ({
  ...sharedOptions,
  nodeTransforms: [...presetNodes, ...DOMNodeTransforms],
  directiveTransforms: { ...presetDirectives, ...DOMDirectiveTransforms },
});

const N = 60;
const timeStage = (f) => {
  for (let i = 0; i < 5; i++) f();
  const t0 = performance.now();
  for (let i = 0; i < N; i++) f();
  return Math.round(((performance.now() - t0) * 1000) / N);
};

const doParse = () => baseParse(tpl, sharedOptions);
const doTransform = () => {
  const ast = baseParse(tpl, sharedOptions);
  transform(ast, makeTransformOptions());
};
const doParseTransformGen = () => {
  const ast = baseParse(tpl, sharedOptions);
  transform(ast, makeTransformOptions());
  generate(ast, { mode: "module", prefixIdentifiers: true });
};
const doCompile = () =>
  compile(tpl, {
    mode: "module",
    prefixIdentifiers: true,
    hoistStatic: true,
    cacheHandlers: true,
  });

const tParse = timeStage(doParse);
const tPT = timeStage(doTransform);
const tPTG = timeStage(doParseTransformGen);
const tCompile = timeStage(doCompile);
say(
  `official(prefix) baseParse=${tParse} transform=${tPT - tParse} codegen=${tPTG - tPT} ` +
    `transform+codegen=${tPTG - tParse} full(compile)=${tCompile} (us/iter)`,
);
