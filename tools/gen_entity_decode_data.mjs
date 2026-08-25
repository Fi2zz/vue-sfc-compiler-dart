// Generate lib/template/entity_decode_data.dart from entities htmlDecodeTree
// (the named-entity decode trie used by @vue/compiler-core). DO NOT EDIT the
// generated Dart file; re-run this script instead.
import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const gen = require("../node_modules/entities/lib/generated/decode-data-html.js");
const tree = Array.from(gen.default);
let out = `// Generated from entities htmlDecodeTree (the named-character-reference
// decode trie bundled with @vue/compiler-core). DO NOT EDIT — regenerate via
// tools/gen_entity_decode_data.mjs.
// ignore_for_file: constant_identifier_names
`;
out += "\nconst List<int> kHtmlDecodeTree = [\n";
for (let i = 0; i < tree.length; i += 20) {
  out += "  " + tree.slice(i, i + 20).join(",") + ",\n";
}
out += "];\n";
writeFileSync("lib/template/entity_decode_data.dart", out);
console.log("written", tree.length, "entries");
