// Options-surface differential probe (official side). Prints one block per
// template x option-combo; diff against tools/_dom_options_probe.dart output.
import { compile } from "@vue/compiler-dom";

const templates = [
  "<div>{{ msg }}</div>",
  '<div v-if="ok">a</div><p v-else>b</p>',
  '<input v-model="x">',
  '<div @click="go">x</div>',
  "<!-- hi --><div>y</div>",
  '<div   class="a"   >  text  </div>',
  "<div>{{ count + 1 }}</div>",
];
const combos = [
  ["module", { mode: "module" }],
  ["hoist", { hoistStatic: true }],
  ["cache", { mode: "module", cacheHandlers: true }],
  ["preserve", { whitespace: "preserve" }],
  ["nocomments", { comments: false }],
  ["ists", { isTS: true }],
  ["custel", { isCustomElement: (t) => t === "input" }],
  ["err49", { cacheHandlers: true }],
];

for (const [label, options] of combos) {
  for (const t of templates) {
    let out;
    try {
      out = compile(t, options).code;
    } catch (e) {
      out = "THROW: " + (e && e.message ? e.message : e);
    }
    console.log(`### ${label} :: ${JSON.stringify(t)}\n${out}\n`);
  }
}
