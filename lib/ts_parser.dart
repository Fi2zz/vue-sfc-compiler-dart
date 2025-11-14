// English comments per ~/REPO rule.
// High-level Dart wrapper for parsing TypeScript/TSX via Tree-sitter FFI.
// Provides AST traversal utilities and conversion to a simple Dart model.

import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'ts_ffi.dart';

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

/// Parser wrapper that manages core and language loading.
class TSParser {
  final TSFFI _ffi = TSFFI.loadCore();

  /// Create instance with loaded core library.
  // static TSParser create() => TSParser._(TSFFI.loadCore());

  /// Parse TypeScript code and return the root AstNode.
  /// If [tsx] is true, uses the TSX grammar.
  /// When [namedOnly] is true, traverses only named children (recommended).
  /// [maxDepth] can be used to limit recursion; set <= 0 for full traversal.
  AstNode parse({
    required String code,
    required String language,
    bool namedOnly = true,
    int maxDepth = 0,
  }) {
    final lang = TSFFI.load(language);
    // Create parser
    final parser = _ffi.tsParserNew();
    try {
      final ok = _ffi.tsParserSetLanguage(parser, lang);
      if (!ok) {
        throw StateError('Failed to set language on parser');
      }

      final codePtr = code.toNativeUtf8();
      try {
        final tree = _ffi.tsParserParseString(
          parser,
          Pointer.fromAddress(0),
          codePtr,
          code.length,
        );
        if (tree.address == 0) {
          throw StateError('Failed to parse input string');
        }
        try {
          final root = _ffi.tsTreeRootNode(tree);
          return _toAst(root, namedOnly: namedOnly, maxDepth: maxDepth);
        } finally {
          _ffi.tsTreeDelete(tree);
        }
      } finally {
        malloc.free(codePtr);
      }
    } finally {
      _ffi.tsParserDelete(parser);
    }
  }

  /// Convert a TSNode into a Dart AstNode with optional depth limit.
  AstNode _toAst(
    TSNode node, {
    required bool namedOnly,
    required int maxDepth,
    int current = 0,
  }) {
    final type = _ffi.tsNodeType(node).toDartString();
    final sp = _ffi.tsNodeStartPoint(node);
    final ep = _ffi.tsNodeEndPoint(node);
    final sb = _ffi.tsNodeStartByte(node);
    final eb = _ffi.tsNodeEndByte(node);

    // Depth handling: if maxDepth > 0 and current >= maxDepth, stop.
    final shouldStop = maxDepth > 0 && current >= maxDepth;
    final children = <AstNode>[];
    if (!shouldStop) {
      final count = namedOnly
          ? _ffi.tsNodeNamedChildCount(node)
          : _ffi.tsNodeChildCount(node);
      for (var i = 0; i < count; i++) {
        final child = namedOnly
            ? _ffi.tsNodeNamedChild(node, i)
            : _ffi.tsNodeChild(node, i);
        children.add(
          _toAst(
            child,
            namedOnly: namedOnly,
            maxDepth: maxDepth,
            current: current + 1,
          ),
        );
      }
    }

    return AstNode(
      type: type,
      startByte: sb,
      endByte: eb,
      startRow: sp.row,
      startColumn: sp.column,
      endRow: ep.row,
      endColumn: ep.column,
      children: children,
    );
  }
}
