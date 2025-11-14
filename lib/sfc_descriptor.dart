import 'package:vue_sfc_parser/block.dart';

/// SFC描述符
class SfcDescriptor {
  final String filename;
  final String source;
  final TemplateBlock? template;
  final ScriptBlock? script;
  final ScriptBlock? scriptSetup;
  final List<StyleBlock> styles;
  final List<SFCBlock> customBlocks;
  SfcDescriptor({
    required this.filename,
    required this.source,
    this.template,
    required this.script,
    required this.styles,
    required this.customBlocks,
    this.scriptSetup,
  });

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'source': source,
      'template': template?.toJson(),
      'script': script?.toJson(),
      'scriptSetup': scriptSetup?.toJson(),
      'styles': styles.map((s) => s.toJson()).toList(),
      'customBlocks': customBlocks.map((b) => b.toJson()).toList(),
    };
  }
}
