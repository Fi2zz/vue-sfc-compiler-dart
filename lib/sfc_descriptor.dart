String _normalizeBlockName(String string) {
  while (string.startsWith('.')) {
    string = string.replaceFirst('.', '').trim();
  }
  while (string.startsWith('_')) {
    string = string.replaceFirst('_', '').trim();
  }

  while (string.contains('.')) {
    string = string.replaceFirst('.', '_');
  }
  return string.replaceAll('/', '').trim();
}

class BlockType {
  static String script = 'script';
  static String template = 'template';
  static String style = 'style';
}

/// SFC块基类
class SFCBlock {
  final String type;
  final String content;
  final Map<String, String> attrs;
  final int locStart;
  final int locEnd;
  final String filename;
  SFCBlock({
    required this.filename,
    required this.type,
    required this.content,
    required this.attrs,
    required this.locStart,
    required this.locEnd,
  });

  /// 获取语言类型
  String? get lang {
    String? attr = attrs['lang'];
    if (attr != null) return attr;
    if (type == BlockType.script) return attr ?? 'js';
    if (type == BlockType.style) return attr ?? 'css';
    return null;
  }

  String? get src => attrs['src'];
  String get name => attrs['name'] ?? _normalizeBlockName(filename);
}

/// 原始块数据
class Raw {
  final String type;
  final String content;
  final Map<String, String> attrs;
  final int locStart;
  final int locEnd;

  Raw({
    required this.type,
    required this.content,
    required this.attrs,
    required this.locStart,
    required this.locEnd,
  });
}

class ScriptBlock extends SFCBlock {
  bool get isSetup => attrs.containsKey('setup');

  ScriptBlock({
    required super.content,
    required super.attrs,
    required super.locStart,
    required super.locEnd,
    required super.filename,
  }) : super(type: BlockType.script);
}

/// 样式块
class StyleBlock extends SFCBlock {
  final bool scoped;
  final String? module;

  StyleBlock({
    required super.content,
    required super.attrs,
    required super.locStart,
    required super.locEnd,
    required super.filename,
    this.scoped = false,
    this.module,
  }) : super(type: BlockType.style);
}

/// 模板块
class TemplateBlock extends SFCBlock {
  TemplateBlock({
    required super.content,
    required super.attrs,
    required super.locStart,
    required super.locEnd,
    required super.filename,
  }) : super(type: BlockType.template);
}

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
}
