// Official-side benchmark: same corpus, methodology and output shape as
// bench/bench.dart, compiling with @vue/compiler-sfc (pinned 3.5.41).
// Usage: node bench/bench_official.mjs [--runs=300] [--warmup=30] [--out=x.json]
import { readFileSync, writeFileSync } from "node:fs";
import { parse, compileScript, compileTemplate, compileStyle } from "@vue/compiler-sfc";

const args = process.argv.slice(2);
const intArg = (key, def) => {
  const hit = args.find((a) => a.startsWith(`${key}=`));
  return hit ? Number(hit.split("=")[1]) || def : def;
};
const strArg = (key, def) => {
  const hit = args.find((a) => a.startsWith(`${key}=`));
  return hit ? hit.split("=")[1] : def;
};
const say = (line) => process.stdout.write(`${line}\n`);
const runs = intArg("--runs", 300);
const warmup = intArg("--warmup", 30);
const out = strArg("--out", "");

// Keep warnings (deprecations etc.) out of both output and timing.
console.log = () => {};
console.warn = () => {};
console.error = () => {};

const shared = JSON.parse(readFileSync("bench/corpus_shared.json", "utf8"));
const typical = (() => {
  const raw = JSON.parse(readFileSync("batch_inputs.json", "utf8"));
  return raw
    .filter((e) => e.kind === "sfc")
    .map((e) => ({ name: e.id, src: e.source }))
    .sort((a, b) => b.src.length - a.src.length)
    .slice(0, 20);
})();
const large = [10, 50].map((m) => {
  const p = `bench/corpus/large_${m}.vue`;
  try {
    return { name: `large_${m}`, src: readFileSync(p, "utf8") };
  } catch {
    return null;
  }
}).filter(Boolean);

function compileOne(src, name) {
  let parsed;
  try {
    parsed = parse(src, { filename: `./${name}.vue` });
  } catch {
    return;
  }
  const d = parsed.descriptor;
  let bindings;
  if (d.scriptSetup || d.script) {
    try {
      bindings = compileScript(d, { id: "data-v-x" }).bindings;
    } catch {
      return;
    }
  }
  if (d.template) {
    try {
      compileTemplate({
        source: d.template.content,
        filename: `./${name}.vue`,
        id: "data-v-x",
        bindingMetadata: bindings,
      });
    } catch {
      return;
    }
  }
  for (const s of d.styles) {
    try {
      compileStyle({
        source: s.content,
        filename: `./${name}.vue`,
        id: "data-v-x",
        scoped: s.scoped,
      });
    } catch {
      return;
    }
  }
}

function compileAll(sources) {
  for (let i = 0; i < sources.length; i++) compileOne(sources[i], `b${i}`);
}

function stats(samples) {
  samples.sort((a, b) => a - b);
  const p50 = samples[Math.floor(samples.length / 2)];
  const p90 = samples[Math.floor(samples.length * 0.9)];
  const mean = Math.round(samples.reduce((a, b) => a + b, 0) / samples.length);
  return { p50, p90, mean, min: samples[0] };
}

function timeTier(name, files) {
  const sources = files.map((f) => f.src);
  for (let i = 0; i < warmup; i++) compileAll(sources);
  const rssBefore = process.memoryUsage.rss();
  const samples = [];
  for (let i = 0; i < runs; i++) {
    const t0 = process.hrtime.bigint();
    compileAll(sources);
    samples.push(Number(process.hrtime.bigint() - t0) / 1000);
  }
  const rssDelta = process.memoryUsage.rss() - rssBefore;
  const s = stats(samples);
  const st = {
    files: files.length,
    bytes: files.reduce((a, f) => a + f.src.length, 0),
    iter_us: s,
    files_per_s_p50: ((files.length * 1e6) / s.p50).toFixed(1),
    rss_delta_bytes: rssDelta,
  };
  say(`${name}: p50=${(s.p50 / 1000).toFixed(2)}ms (${st.files_per_s_p50} files/s)`);
  return st;
}

const tiers = {};
for (const [key, srcs] of Object.entries(shared)) {
  tiers[key] = timeTier(key, srcs.map((src, i) => ({ name: `f${i}`, src })));
}
tiers.typical = timeTier("typical", typical);
tiers.large = timeTier("large", large);

const result = {
  env: {
    node: process.version,
    os: `${process.platform} ${process.arch}`,
    cores: process.availableParallelism?.() ?? "",
    mode: "jit(v8)",
    timestamp: new Date().toISOString(),
  },
  tiers,
  concurrency: null,
};
if (out) {
  writeFileSync(out, JSON.stringify(result, null, 2));
}
say(`written ${out}`);
