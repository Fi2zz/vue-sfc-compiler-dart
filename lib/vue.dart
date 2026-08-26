/// 最小化的Vue SFC解析器
/// 提供基本的SFC解析功能
library;

import 'sfc_compile_script.dart';
import 'sfc_compiler.dart';
import 'sfc_descriptor.dart';
import 'sfc_error.dart';
import 'sfc_parser.dart';
import 'script/options_bindings.dart';
import 'script/script_compile.dart';
import 'template/compile_template.dart';
// export './sfc_compiler.dart' show CompileResult;

/// parseCollecting 的返回：descriptor + 官方风格的错误消息列表。
final class SfcParseOutcome {
  final SfcDescriptor? descriptor;
  final List<String> errors;
  SfcParseOutcome(this.descriptor, this.errors);
}

/// Vue SFC 编译器主类
class Vue {
  static SfcDescriptor parse(String source, {required String filename}) {
    final parser = SfcParser(source, filename: filename);
    return parser.parse();
  }

  /// Official parse() semantics: never throws for structural problems,
  /// returns descriptor + collected error messages (including template
  /// content parse errors surfaced by the full-source tokenize pass).
  static SfcParseOutcome parseCollecting(
    String source, {
    required String filename,
  }) {
    try {
      final descriptor = parse(source, filename: filename);
      final errors = <String>[];
      final template = descriptor.template;
      if (template != null) {
        errors.addAll(
          collectTemplateParseErrors(template.content).map((e) => e.message),
        );
      }
      return SfcParseOutcome(descriptor, errors);
    } catch (e) {
      final message = e is SfcError ? e.message ?? '$e' : '$e';
      return SfcParseOutcome(null, [message]);
    }
  }

  static CompileResult compile(String source, {required String filename}) {
    SfcDescriptor descriptor = parse(source, filename: filename);
    String script = compileScript(descriptor);
    String template = compileTemplate(descriptor);
    List<String> styles = compileStyles(descriptor);
    return CompileResult(
      template: template,
      script: script,
      styles: styles,
      metadata: {},
    );
  }

  /// bindingMetadata for the standalone compileTemplate API: run the full
  /// script compilation (official flow derives bindings as a side product)
  /// and return the resulting bindings map. Null when no <script setup>.
  static Map<String, String>? bindingMetadataOf(SfcDescriptor descriptor) {
    if (descriptor.scriptSetup != null) {
      return compileScriptSetup(descriptor).bindings;
    }
    final script = descriptor.script;
    if (script == null) return null;
    // 官方：非 js/ts 脚本直接返回原块，无 bindings。
    final lang = script.lang ?? 'js';
    if (!const ['js', 'jsx', 'ts', 'tsx'].contains(lang)) return null;
    return analyzeScriptBindings(script.content, lang);
  }
}
