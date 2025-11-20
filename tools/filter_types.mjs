import fs from "fs";
import ts from "typescript";

const filePath = process.argv[2];
if (!filePath) {
  console.error("Usage: node tools/filter_types.mjs <path-to-ts-file>");
  process.exit(1);
}

const text = fs.readFileSync(filePath, "utf8");
const sf = ts.createSourceFile(filePath, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);

function isKeepNode(node) {
  return node.kind === ts.SyntaxKind.InterfaceDeclaration || node.kind === ts.SyntaxKind.TypeAliasDeclaration;
}

function sliceWithLeadingComments(node, sourceText) {
  const start = node.getFullStart();
  const end = node.end;
  return sourceText.slice(start, end);
}

const kept = [];
for (const stmt of sf.statements) {
  if (isKeepNode(stmt)) {
    kept.push(sliceWithLeadingComments(stmt, text));
  }
}

const output = kept.join("\n\n");
fs.writeFileSync(filePath, output, "utf8");

// quick validation: parse the output and ensure only type/interface remain
const outText = fs.readFileSync(filePath, "utf8");
const outSf = ts.createSourceFile(filePath, outText, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
for (const stmt of outSf.statements) {
  if (!isKeepNode(stmt)) {
    console.error("Non-type/interface statement found after filtering: " + ts.SyntaxKind[stmt.kind]);
    process.exit(2);
  }
}
console.log("Filtered types/interfaces count:", kept.length);