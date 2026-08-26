import 'block.dart';
import 'sfc_descriptor.dart';
import 'sfc_error.dart';
import 'script/css_vars.dart';

/// 最小化的SFC解析器实现
class SfcParser {
  final String source;
  final String filename;

  SfcParser(this.source, {required this.filename});

  SfcDescriptor parse() {
    final blocks = _parseBlocks();

    // 解析各个块
    TemplateBlock? template;
    ScriptBlock? script;
    final styles = <StyleBlock>[];
    final customBlocks = <SFCBlock>[];
    ScriptBlock? scriptSetup;

    for (final block in blocks) {
      switch (block.type) {
        case 'template':
          // 官方：Vue 3 不再支持 <template functional>。
          if (block.attrs.containsKey('functional')) {
            throw SfcError(
              message:
                  '<template functional> is no longer supported in Vue 3, '
                  'since functional components no longer have significant '
                  'performance difference from stateful ones. Just use a '
                  'normal <template> instead.',
              locStart: block.locStart,
              locEnd: block.locEnd,
            );
          }
          if (template != null) {
            throw DuplicateBlockError(
              type: 'template',
              locStart: block.locStart,
              locEnd: block.locEnd,
            );
          }

          template = TemplateBlock(
            content: block.content,
            attrs: block.attrs,
            locStart: block.locStart,
            locEnd: block.locEnd,
            filename: filename,
          );
          break;
        case 'script':
          // 官方语义：内容为空（含纯空白/自闭合）的 script 块不视为
          // “存在”；但带 src 的外链块仍登记（官方 compileScript 原样透传）。
          final hasContent = block.content.trim().isNotEmpty;
          final isExternal = block.attrs.containsKey('src');
          if (!hasContent && !isExternal) break;
          final b = ScriptBlock(
            content: block.content,
            attrs: block.attrs,
            locStart: block.locStart,
            locEnd: block.locEnd,
            filename: filename,
          );

          if (block.attrs.containsKey('setup')) {
            if (scriptSetup != null) {
              throw DuplicateBlockError(
                type: 'script setup',
                locStart: block.locStart,
                locEnd: block.locEnd,
              );
            }
            scriptSetup = b;
            break;
          } else if (script == null) {
            script = b;

            break;
          } else {
            // 官方：普通 <script> 也只允许出现一次。
            throw DuplicateBlockError(
              type: 'script',
              locStart: block.locStart,
              locEnd: block.locEnd,
            );
          }
        case 'style':
          styles.add(
            StyleBlock(
              content: block.content,
              attrs: block.attrs,
              locStart: block.locStart,
              locEnd: block.locEnd,
              scoped: block.attrs.containsKey('scoped'),
              module: block.attrs['module'],
              filename: filename,
            ),
          );
          break;
        default:
          customBlocks.add(
            SFCBlock(
              type: block.type,
              content: block.content,
              attrs: block.attrs,
              locStart: block.locStart,
              locEnd: block.locEnd,
              filename: filename,
            ),
          );
      }
    }

    if (template == null && script == null && scriptSetup == null) {
      throw MissingTemplateOrScript(
        locStart: 0,
        locEnd: source.length,
        filename: filename,
      );
    }

    if (scriptSetup != null && scriptSetup.attrs.containsKey('src')) {
      throw ScriptSetupAttributeError(
        locStart: scriptSetup.locStart,
        locEnd: scriptSetup.locEnd,
      );
    }

    if (scriptSetup != null &&
        script != null &&
        script.attrs.containsKey('src')) {
      throw ScriptSrcAttributeError(
        locStart: script.locStart,
        locEnd: script.locEnd,
      );
    }

    if (scriptSetup != null &&
        script != null &&
        scriptSetup.attrs['lang'] != script.attrs['lang']) {
      throw ScriptLangMismatchError(
        locStart: scriptSetup.locStart,
        locEnd: scriptSetup.locEnd,
      );
    }

    return SfcDescriptor(
      filename: filename,
      source: source,
      template: template,
      script: script,
      styles: styles,
      customBlocks: customBlocks,
      scriptSetup: scriptSetup,
      cssVars: parseCssVars(styles.map((s) => s.content)),
    );
  }

  /// 解析所有块（深度感知：仅顶层元素算 block，与官方 SFC parse 一致——
  /// 模板内容里嵌套的 `<template>` 是内容而非块）。
  List<Raw> _parseBlocks() {
    final blocks = <Raw>[];
    var i = 0;
    while (i < source.length) {
      final block = _nextBlock(i);
      if (block == null) break;
      blocks.add(block);
      i = block.locEnd;
    }
    return blocks;
  }

  /// 从 from 起扫描下一个顶层块；没有则返回 null。
  Raw? _nextBlock(int from) {
    var i = from;
    while (i < source.length) {
      final lt = source.indexOf('<', i);
      if (lt < 0) return null;
      if (source.startsWith('<!--', lt)) {
        i = _skipComment(lt);
        continue;
      }
      final name = _tagNameAt(lt + 1);
      if (name == null) {
        i = lt + 1;
        continue;
      }
      return _buildBlock(name, lt);
    }
    return null;
  }

  /// 构建 openLt 处 `<name>` 标签对应的块（含同名嵌套的闭合匹配）。
  Raw _buildBlock(String name, int openLt) {
    final openEnd = _tagEnd(openLt);
    final selfClosing = source[openEnd - 2] == '/';
    final attrEnd = selfClosing ? openEnd - 2 : openEnd - 1;
    final attrs =
        _parseAttributes(source.substring(openLt + 1 + name.length, attrEnd));
    if (selfClosing) {
      return Raw(
          type: name.toLowerCase(), content: '', attrs: attrs,
          locStart: openLt, locEnd: openEnd);
    }
    final closeStart = _findCloseStart(name, openEnd);
    // 官方 X_MISSING_END_TAG：闭合标签缺失（扫描到 EOF）。
    if (closeStart >= source.length &&
        _matchCloseTag(name, closeStart) <= 0) {
      throw UnclosedBlockError(locStart: closeStart, locEnd: closeStart);
    }
    return Raw(
      type: name.toLowerCase(),
      content: source.substring(openEnd, closeStart).trim(),
      attrs: attrs,
      locStart: openLt,
      locEnd: _closeTagEnd(name, closeStart),
    );
  }

  /// 找到与 `<name>` 匹配的闭合标签起点；同名嵌套加深，未闭合返回末尾。
  int _findCloseStart(String name, int from) {
    var depth = 1;
    var i = from;
    while (i < source.length) {
      final lt = source.indexOf('<', i);
      if (lt < 0) break;
      if (source.startsWith('<!--', lt)) {
        i = _skipComment(lt);
      } else if (_matchCloseTag(name, lt) > 0) {
        if (--depth == 0) return lt;
        i = _matchCloseTag(name, lt);
      } else {
        final next = _afterNestedOpen(name, lt);
        if (next > 0) depth++;
        i = next > 0 ? next : lt + 1;
      }
    }
    return source.length;
  }

  /// lt 处若是同名嵌套开标签（非自闭合），返回其之后的位置；否则 -1。
  int _afterNestedOpen(String name, int lt) {
    final openName = _tagNameAt(lt + 1);
    if (openName == null || openName.toLowerCase() != name.toLowerCase()) {
      return -1;
    }
    final end = _tagEnd(lt);
    return source[end - 2] == '/' ? -1 : end;
  }

  /// lt 处若是 `</name\s*>` 闭合标签，返回其结束位置；否则 -1。
  int _matchCloseTag(String name, int lt) {
    final match =
        RegExp('</$name\\s*>', caseSensitive: false).matchAsPrefix(source, lt);
    return match == null ? -1 : match.end;
  }

  /// 闭合标签之后的位置；未闭合（closeStart 在末尾）时即 source.length。
  int _closeTagEnd(String name, int closeStart) {
    if (closeStart >= source.length) return source.length;
    final end = _matchCloseTag(name, closeStart);
    return end > 0 ? end : source.length;
  }

  /// 跳过 <!-- --> 注释，返回注释之后的位置。
  int _skipComment(int at) {
    final close = source.indexOf('-->', at + 4);
    return close < 0 ? source.length : close + 3;
  }

  /// 读取 at 处的标签名（字母开头的 [\w-]+）；非开标签返回 null。
  String? _tagNameAt(int at) {
    if (at >= source.length || !_isAlpha(source.codeUnitAt(at))) return null;
    var end = at + 1;
    while (end < source.length && _tagNameChar.hasMatch(source[end])) {
      end++;
    }
    return source.substring(at, end);
  }

  static final _tagNameChar = RegExp(r'[\w-]');

  static bool _isAlpha(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);

  /// 返回开标签 '>' 之后的位置（引号内的 '>' 不算）；未闭合返回末尾。
  int _tagEnd(int openLt) {
    String? quote;
    for (var i = openLt + 1; i < source.length; i++) {
      final ch = source[i];
      if (quote != null) {
        if (ch == quote) quote = null;
      } else if (ch == '"' || ch == "'") {
        quote = ch;
      } else if (ch == '>') {
        return i + 1;
      }
    }
    return source.length;
  }

  /// 解析属性（引号感知：值内空格不切断，如 srcset=" "）。
  Map<String, String> _parseAttributes(String attrString) {
    final attrs = <String, String>{};
    final s = attrString;
    var i = 0;
    while (i < s.length) {
      while (i < s.length && _isWs(s.codeUnitAt(i))) {
        i++;
      }
      if (i >= s.length) break;
      final keyStart = i;
      while (i < s.length && !_isWs(s.codeUnitAt(i)) && s[i] != '=') {
        i++;
      }
      final key = s.substring(keyStart, i);
      var value = 'true';
      if (i < s.length && s[i] == '=') {
        i++;
        if (i < s.length && (s[i] == '"' || s[i] == "'")) {
          final quote = s[i];
          i++;
          final vStart = i;
          while (i < s.length && s[i] != quote) {
            i++;
          }
          value = s.substring(vStart, i);
          if (i < s.length) i++;
        } else {
          final vStart = i;
          while (i < s.length && !_isWs(s.codeUnitAt(i))) {
            i++;
          }
          value = s.substring(vStart, i);
        }
      }
      if (key.isNotEmpty) attrs[key] = value;
    }
    return attrs;
  }

  static bool _isWs(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;
}
