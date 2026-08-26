// English comments per ~/REPO rule.
// High-level Dart wrapper for parsing TypeScript/TSX.
// Backend: oxc cdylib via FFI since Phase 4 (see OXC_REFERENCE.md); the
// mapper reproduces the tree-sitter CST shapes the consumers depend on.

import 'dart:convert';
import 'dart:io';

import 'ts_syntax/oxc_ffi.dart';
import 'ts_syntax/est_node.dart';
import 'ts_syntax/oxc_mapper.dart';

/// Dev-only corpus recorder: when TS_AST_CORPUS points to a file, every
/// parse() input is appended as one JSON line for the ast_diff harness.
void recordCorpusEntry(String code, String language) {
  final path = Platform.environment['TS_AST_CORPUS'];
  if (path == null || path.isEmpty) return;
  final line = jsonEncode({'code': code, 'language': language});
  File(path).writeAsStringSync('$line\n', mode: FileMode.append);
}

class AstNode {
  final String type;
  final int startByte;
  final int endByte;
  final int startRow;
  final int startColumn;
  final int endRow;
  final int endColumn;
  final List<AstNode> children;
  AstNode({
    required this.type,
    required this.startByte,
    required this.endByte,
    required this.startRow,
    required this.startColumn,
    required this.endRow,
    required this.endColumn,
    required this.children,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'startByte': startByte,
    'endByte': endByte,
    'start': {'row': startRow, 'column': startColumn},
    'end': {'row': endRow, 'column': endColumn},
    'children': children.map((c) => c.toJson()).toList(),
  };

  @override
  String toString() => 'AstNode(type=$type, children=${children.length})';
}

/// Parser wrapper: oxc FFI + ESTree-to-tree-sitter mapper.
class TSParser {
  /// Parse [code] in [language] (ts/tsx/js/jsx) and return the root AstNode
  /// in tree-sitter-compatible shape. [namedOnly] and [maxDepth] are kept
  /// for signature compatibility; the mapper always produces a full
  /// named-children tree. Inputs oxc cannot parse (parser panic, e.g. the
  /// exempt errorRecovery family) yield a program holding one ERROR node.
  AstNode parse({
    required String code,
    required String language,
    bool namedOnly = true,
    int maxDepth = 0,
  }) {
    recordCorpusEntry(code, language);
    final mapper = OxcMapper(code, language: language);
    try {
      final payload = OxcFFI.load().parseJson(code, language);
      return mapper.mapProgram(estOf(payload));
    } on OxcParseException {
      return mapper.errorTree();
    }
  }
}
