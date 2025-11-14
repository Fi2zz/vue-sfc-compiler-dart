String normalizeBlockName(String string) {
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
  String? get lang => attrs['lang'];
  String? get src => attrs['src'];
  String get name => attrs['name'] ?? normalizeBlockName(filename);

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
      'attrs': attrs,
      'loc': {'start': locStart, 'end': locEnd},
    };
  }
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
  ScriptBlock({
    required super.content,
    required super.attrs,
    required super.locStart,
    required super.locEnd,
    required super.filename,
  }) : super(type: 'script');
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
  }) : super(type: 'style');

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['scoped'] = scoped;
    json['module'] = module;
    return json;
  }
}

/// 模板块
class TemplateBlock extends SFCBlock {
  TemplateBlock({
    required super.content,
    required super.attrs,
    required super.locStart,
    required super.locEnd,
    required super.filename,
  }) : super(type: 'template');
}
