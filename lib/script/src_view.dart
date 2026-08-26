// Source view utilities: convert tree-sitter byte offsets to Dart string
// (UTF-16 code unit) offsets, plus small AstNode navigation helpers.
import 'dart:convert';

import '../ts_parser.dart';

final class SrcView {
  final String content;
  // Pure-ASCII fast path: byte offset == char offset, so the map is null and
  // charOf clamps against content.length (identical results to a built map).
  late final List<int>? _byteToChar = _buildMap(content);

  SrcView(this.content);

  static List<int>? _buildMap(String s) {
    var asciiOnly = true;
    for (var i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) > 0x7F) {
        asciiOnly = false;
        break;
      }
    }
    if (asciiOnly) return null;
    final bytes = utf8.encode(s);
    final map = List<int>.filled(bytes.length + 1, 0);
    var charIndex = 0;
    var byteIndex = 0;
    for (final rune in s.runes) {
      final len = rune > 0xFFFF ? 2 : 1;
      final byteLen = rune > 0x7FF
          ? (rune > 0xFFFF ? 4 : 3)
          : (rune > 0x7F ? 2 : 1);
      for (var b = 0; b < byteLen; b++) {
        map[byteIndex + b] = charIndex;
      }
      byteIndex += byteLen;
      charIndex += len;
    }
    map[bytes.length] = s.length;
    return map;
  }

  /// Convert a tree-sitter byte offset into a Dart string offset.
  int charOf(int byteOffset) {
    final map = _byteToChar;
    if (map == null) return byteOffset.clamp(0, content.length);
    final clamped = byteOffset.clamp(0, map.length - 1);
    return map[clamped];
  }

  /// Slice [content] by tree-sitter byte offsets.
  String slice(int startByte, int endByte) {
    return content.substring(charOf(startByte), charOf(endByte));
  }

  String textOf(AstNode node) => slice(node.startByte, node.endByte);
}

AstNode? childOfType(AstNode node, String type) {
  for (final c in node.children) {
    if (c.type == type) return c;
  }
  return null;
}

List<AstNode> childrenOfType(AstNode node, String type) {
  return node.children.where((c) => c.type == type).toList(growable: false);
}

AstNode? findDeep(AstNode node, String type) {
  for (final c in node.children) {
    if (c.type == type) return c;
    final r = findDeep(c, type);
    if (r != null) return r;
  }
  return null;
}
