import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/sfc_error.dart';

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
          final b = ScriptBlock(
            content: block.content,
            attrs: block.attrs,
            locStart: block.locStart,
            locEnd: block.locEnd,
            filename: filename,
          );

          if (b.isSetup) {
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
    );
  }

  /// 解析所有块
  List<Raw> _parseBlocks() {
    final blocks = <Raw>[];
    final regex = RegExp(
      r'<(template|script|style|[\w-]+)\s*([^>]*)>([\s\S]*?)<\/\1>',
      caseSensitive: false,
      multiLine: true,
    );

    final matches = regex.allMatches(source);
    for (final match in matches) {
      final type = match.group(1)!.toLowerCase();
      final attrString = match.group(2) ?? '';
      final content = match.group(3)!;
      final start = match.start;
      final end = match.end;

      // 跳过被 HTML 注释包裹的区块，例如：<!-- <script>...</script> -->
      if (_isWithinHtmlComment(start, end)) {
        continue;
      }

      final attrs = _parseAttributes(attrString);

      blocks.add(
        Raw(
          type: type,
          content: content.trim(),
          attrs: attrs,
          locStart: start,
          locEnd: end,
        ),
      );
    }

    return blocks;
  }

  // 简单检测 [start, end] 是否位于 HTML 注释区域内：<!-- ... -->
  bool _isWithinHtmlComment(int start, int end) {
    final lastOpenBeforeStart = source.lastIndexOf('<!--', start);
    if (lastOpenBeforeStart < 0) return false;
    final lastCloseBeforeStart = source.lastIndexOf('-->', start);
    // 若最近一次打开在最近一次关闭之后，说明 start 时处于注释内
    final insideAtStart = lastOpenBeforeStart > lastCloseBeforeStart;
    if (!insideAtStart) return false;
    // 进一步确认在 end 之后存在关闭标记，避免未闭合误判
    final closeAfterEnd = source.indexOf('-->', end);
    return closeAfterEnd >= 0;
  }

  /// 解析属性
  Map<String, String> _parseAttributes(String attrString) {
    final attrs = <String, String>{};
    // 简化的属性解析，避免复杂的正则表达式
    final parts = attrString.trim().split(RegExp(r'\s+'));

    for (final part in parts) {
      if (part.contains('=')) {
        final keyValue = part.split('=');
        if (keyValue.length == 2) {
          final key = keyValue[0];
          var value = keyValue[1];
          // 移除引号
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          } else if (value.startsWith("'") && value.endsWith("'")) {
            value = value.substring(1, value.length - 1);
          }
          attrs[key] = value;
        }
      } else if (part.isNotEmpty) {
        attrs[part] = 'true';
      }
    }

    return attrs;
  }
}
