/// 最小化的Vue SFC解析器
/// 提供基本的SFC解析功能
library;

import 'package:vue_sfc_parser/sfc_compile_script.dart';
import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/sfc_parser.dart';
// export './sfc_compiler.dart' show CompileResult;

/// Vue SFC 编译器主类
class Vue {
  static SfcDescriptor parse(String source, {required String filename}) {
    final parser = SfcParser(source, filename: filename);
    return parser.parse();
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
}
