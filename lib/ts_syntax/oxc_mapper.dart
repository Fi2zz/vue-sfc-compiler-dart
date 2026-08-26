// English comments per ~/REPO rule.
// oxc ESTree JSON -> tree-sitter-shaped AstNode mapper.
// Entry point and shared span/position machinery; the node-family mappings
// live in mapper_expr.dart / mapper_stmt.dart / mapper_type.dart as
// extensions on OxcMapper.

import 'dart:convert';
import 'dart:typed_data';

import 'package:vue_sfc_parser/ts_parser.dart';

part 'mapper_expr.dart';
part 'mapper_stmt.dart';
part 'mapper_type.dart';

/// Maps one oxc payload to a tree-sitter-compatible AstNode tree.
/// All offsets are UTF-8 bytes; scanning happens on the encoded bytes so
/// multi-byte characters never shift positions.
class OxcMapper {
  final String code;

  /// tree-sitter's javascript and typescript grammars differ in several
  /// node shapes (required_parameter, class heritage, field names).
  final bool tsMode;
  late final Uint8List bytes = utf8.encode(code);
  late final List<int> lineStarts = _buildLineStarts();

  OxcMapper(this.code, {String language = 'ts'})
    : tsMode = language != 'js' && language != 'jsx';

  /// Map a full oxc payload ({program, comments, diagnostics}) to a program
  /// AstNode. Comments are woven into the tree as named children at their
  /// source positions, matching tree-sitter's extra attachment. The program
  /// node starts at its first child and always ends at end of input.
  AstNode mapProgram(Map<String, dynamic> payload) {
    final program = payload['program'] as Map<String, dynamic>;
    final body = program['body'] as List;
    final comments = payload['comments'] as List? ?? const [];
    final children = [for (final s in body) mapStatement(_m(s))];
    var start = children.isEmpty ? skipWs(0) : children.first.startByte;
    if (comments.isNotEmpty) {
      final firstComment = _m(comments.first)['start'] as int;
      if (children.isNotEmpty && firstComment < start) start = firstComment;
    }
    final root = buildNode('program', start, bytes.length, children);
    _weaveComments(root, comments);
    return root;
  }

  /// Fallback tree for inputs oxc cannot parse (parser panic): a program
  /// holding a single ERROR node spanning the input. The only consumer of
  /// ERROR nodes (transform_expression._hasErrorNode) needs the boolean
  /// signal; behavior matches tree-sitter's error recovery for the
  /// already-exempt babel errorRecovery family.
  AstNode errorTree() {
    final error = buildNode('ERROR', 0, bytes.length, const []);
    return buildNode('program', 0, bytes.length, [error]);
  }

  /// Attach every comment to the deepest node whose span contains it.
  void _weaveComments(AstNode root, List comments) {
    for (final c in comments) {
      final j = _m(c);
      final node = buildNode(
        'comment',
        j['start'] as int,
        j['end'] as int,
        const [],
      );
      _insertComment(root, node);
    }
  }

  /// Descend into the deepest containing child, then insert in order.
  void _insertComment(AstNode node, AstNode comment) {
    for (final child in node.children) {
      final contains =
          child.startByte <= comment.startByte &&
          comment.endByte <= child.endByte;
      if (contains) {
        _insertComment(child, comment);
        return;
      }
    }
    var index = node.children.length;
    for (var i = 0; i < node.children.length; i++) {
      if (node.children[i].startByte > comment.startByte) {
        index = i;
        break;
      }
    }
    node.children.insert(index, comment);
  }

  /// Build an AstNode computing row/column points from the line index.
  AstNode buildNode(String type, int start, int end, List<AstNode?> kids) {
    final children = [for (final c in kids) ?c];
    final sp = pointAt(start);
    final ep = pointAt(end);
    return AstNode(
      type: type,
      startByte: start,
      endByte: end,
      startRow: sp.$1,
      startColumn: sp.$2,
      endRow: ep.$1,
      endColumn: ep.$2,
      children: children,
    );
  }

  /// (row, byteColumn) for a byte offset, matching tree-sitter semantics.
  /// Binary search over the line table: O(log lines) per point instead of
  /// O(lines); buildNode calls this twice per node.
  (int, int) pointAt(int offset) {
    var lo = 0;
    var hi = lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return (lo, offset - lineStarts[lo]);
  }

  List<int> _buildLineStarts() {
    final starts = <int>[0];
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0x0A) starts.add(i + 1);
    }
    return starts;
  }

  // ---- shared byte-scanning helpers ----

  static const _ws = {0x20, 0x09, 0x0A, 0x0D};

  /// First non-whitespace byte at or after [i].
  int skipWs(int i) {
    while (i < bytes.length && _ws.contains(bytes[i])) {
      i++;
    }
    return i;
  }

  /// Last non-whitespace byte position before [i] (exclusive).
  int skipWsBack(int i) {
    while (i > 0 && _ws.contains(bytes[i - 1])) {
      i--;
    }
    return i;
  }

  /// Extend a statement end past a following `;` (tree-sitter includes the
  /// semicolon in statement spans, ESTree does not).
  int extendStatementEnd(int end) {
    final i = skipWs(end);
    if (i < bytes.length && bytes[i] == 0x3B) return i + 1;
    return end;
  }

  /// Span of the parenthesized condition around an ESTree condition node:
  /// tree-sitter wraps if/while/do/switch conditions in
  /// parenthesized_expression including the parens.
  (int, int) parenSpanAround(int start, int end) {
    final open = skipWsBack(start) - 1;
    final close = skipWs(end);
    return (open, close + 1);
  }

  // ---- JSON helpers ----

  Map<String, dynamic> _m(Object? v) => v as Map<String, dynamic>;

  /// Dispatch a JSON node to its statement or expression mapping.
  AstNode mapNode(Map<String, dynamic> n) {
    if (statementTypes.contains(n['type'])) return mapStatement(n);
    return mapExpression(n);
  }
}

/// Node types handled by the statement mapper.
const statementTypes = {
  'VariableDeclaration',
  'FunctionDeclaration',
  'ClassDeclaration',
  'ExpressionStatement',
  'BlockStatement',
  'IfStatement',
  'ForStatement',
  'ForInStatement',
  'ForOfStatement',
  'WhileStatement',
  'DoWhileStatement',
  'SwitchStatement',
  'TryStatement',
  'ThrowStatement',
  'ReturnStatement',
  'BreakStatement',
  'ContinueStatement',
  'LabeledStatement',
  'DebuggerStatement',
  'EmptyStatement',
  'ImportDeclaration',
  'ExportNamedDeclaration',
  'ExportDefaultDeclaration',
  'ExportAllDeclaration',
  'TSInterfaceDeclaration',
  'TSTypeAliasDeclaration',
  'TSEnumDeclaration',
  'TSModuleDeclaration',
  'TSDeclareFunction',
};
