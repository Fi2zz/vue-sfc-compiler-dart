// Port of compiler-core codegen.ts: generate() + genNode* family.
// Sourcemap emission mirrors createCodegenContext's push(newlineIndex, node).
import 'dart:convert';

import 'codegen_nodes_gen.dart';
import 'js_nodes.dart';
import 'shared_utils.dart';
import 'source_map.dart';
import 'tmpl_ast.dart';

const pureAnnotation = '/*@__PURE__*/';

final class CodegenOptions {
  String mode = 'module';
  bool prefixIdentifiers = true;
  String filename = 'template.vue.html';
  String? scopeId;
  bool optimizeImports = false;
  String runtimeModuleName = 'vue';
  bool ssr = false;
  bool isTS = false;
  bool inSSR = false;
  bool inline = false;
  bool sourceMap = false;
  Map<String, String>? bindingMetadata;
}

final class CodegenContext {
  final CodegenOptions options;
  final String source;
  final StringBuffer _buf = StringBuffer();
  int indentLevel = 0;
  bool pure = false;
  // 官方 context 的生成位置跟踪（1-based line/column）。
  int line = 1;
  int column = 1;
  int offset = 0;
  SourceMapGenerator? map;

  CodegenContext(RootNode ast, this.options) : source = _sourceOf(ast) {
    if (options.sourceMap) {
      map = SourceMapGenerator()
        ..setSourceContent(options.filename, source);
    }
  }

  static String _sourceOf(RootNode ast) => ast.loc.source;

  String get code => _buf.toString();

  /// 官方 push(code, newlineIndex = -2, node)：
  /// -2=None 纯横向；-1=End 以换行结尾；0=Start 以换行开头；
  /// -3=Unknown 扫描推进；node 非空且 map 开启时记录起止映射。
  void push(String code, {int newlineIndex = -2, Object? node}) {
    _buf.write(code);
    final m = map;
    if (m == null) return;
    final TmplLoc? nloc = switch (node) {
      TmplNode n => n.loc,
      CodegenNode n => n.loc,
      _ => null,
    };
    if (node != null && nloc != null && nloc.source.isNotEmpty) {
      String? name;
      if (node is SimpleExpression && !node.static_) {
        final content = node.content.replaceFirst(RegExp('^_ctx\\.'), '');
        if (content != node.content && isSimpleIdentifier(content)) {
          name = content;
        }
      }
      _addMapping(nloc.start, name);
    }
    if (newlineIndex == -3) {
      _advance(code);
    } else {
      offset += code.length;
      if (newlineIndex == -2) {
        column += code.length;
      } else {
        var ni = newlineIndex;
        if (ni == -1) ni = code.length - 1;
        line++;
        column = code.length - ni;
      }
    }
    if (node != null && nloc != null && nloc.source.isNotEmpty) {
      _addMapping(nloc.end, null);
    }
  }

  void _addMapping(TmplPosition pos, String? name) {
    map!.addMapping(SourceMapMapping(
      originalLine: pos.line,
      originalColumn: pos.column - 1,
      generatedLine: line,
      generatedColumn: column - 1,
      source: options.filename,
      name: name,
    ));
  }

  void _advance(String code) {
    for (var i = 0; i < code.length; i++) {
      if (code.codeUnitAt(i) == 10) {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    offset += code.length;
  }

  void indent() => _newline(++indentLevel);

  void deindent([bool withoutNewLine = false]) {
    if (withoutNewLine) {
      --indentLevel;
    } else {
      _newline(--indentLevel);
    }
  }

  void newline() => _newline(indentLevel);

  void _newline(int n) => push('\n${'  ' * n}', newlineIndex: 0);

  String helper(String name) => '_$name';
}

final class CodegenResult {
  final RootNode ast;
  final String code;
  final String preamble;
  final Map<String, Object?>? map;
  CodegenResult(this.ast, this.code, this.preamble, [this.map]);
}

CodegenResult generate(RootNode ast, CodegenOptions options) {
  final context = CodegenContext(ast, options);
  final isSetupInlined = options.inline;
  final preambleContext =
      isSetupInlined ? CodegenContext(ast, options) : context;
  if (options.mode == 'module') {
    _genModulePreamble(
        ast, preambleContext, options.scopeId != null, isSetupInlined);
  } else {
    _genFunctionPreamble(ast, preambleContext);
  }
  _genRenderFunction(ast, context, options);
  return CodegenResult(ast, context.code,
      isSetupInlined ? preambleContext.code : '',
      context.map?.toJSON(file: options.filename));
}

void _genRenderFunction(
    RootNode ast, CodegenContext context, CodegenOptions options) {
  final functionName = options.ssr ? 'ssrRender' : 'render';
  final args = options.ssr
      ? ['_ctx', '_push', '_parent', '_attrs']
      : ['_ctx', '_cache'];
  if (options.bindingMetadata != null && !options.inline) {
    args.addAll(['\$props', '\$setup', '\$data', '\$options']);
  }
  final signature = options.isTS
      ? args.map((arg) => '$arg: any').join(',')
      : args.join(', ');
  if (options.inline) {
    context.push('($signature) => {');
  } else {
    context.push('function $functionName($signature) {');
  }
  context.indent();
  _genAssetsAndTemps(ast, context);
  if (!options.ssr) context.push('return ');
  if (ast.codegenNode != null) {
    genNode(ast.codegenNode, context);
  } else {
    context.push('null');
  }
  context.deindent();
  context.push('}');
}

void _genAssetsAndTemps(RootNode ast, CodegenContext context) {
  if (ast.components.isNotEmpty) {
    _genAssets(ast.components, 'component', context);
    if (ast.directives.isNotEmpty || ast.temps > 0) context.newline();
  }
  if (ast.directives.isNotEmpty) {
    _genAssets(ast.directives, 'directive', context);
    if (ast.temps > 0) context.newline();
  }
  if (ast.temps > 0) {
    context.push('let ');
    for (var i = 0; i < ast.temps; i++) {
      context.push('${i > 0 ? ', ' : ''}_temp$i');
    }
  }
  if (ast.components.isNotEmpty ||
      ast.directives.isNotEmpty ||
      ast.temps > 0) {
    context.push('\n', newlineIndex: 0);
    context.newline();
  }
}

void _genAssets(List<String> assets, String type, CodegenContext context) {
  final resolver = context
      .helper(type == 'filter' ? hResolveFilter : type == 'component' ? hResolveComponent : hResolveDirective);
  for (var i = 0; i < assets.length; i++) {
    var id = assets[i];
    final maybeSelfReference = id.endsWith('__self');
    if (maybeSelfReference) id = id.substring(0, id.length - 6);
    final isTs = context.options.isTS ? '!' : '';
    final self = maybeSelfReference ? ', true' : '';
    context.push(
        'const ${toValidAssetId(id, type)} = $resolver(${jsonEncode(id)}$self)$isTs');
    if (i < assets.length - 1) context.newline();
  }
}

void _genModulePreamble(RootNode ast, CodegenContext context, bool genScopeId,
    bool inline) {
  if (ast.helpers.isNotEmpty) {
    final helpers = ast.helpers.toList();
    if (context.options.optimizeImports) {
      context.push(
          'import { ${helpers.join(', ')} } from ${jsonEncode(context.options.runtimeModuleName)}\n',
          newlineIndex: -1);
      context.push(
          '\n// Binding optimization for webpack code-split\nconst ${helpers.map((s) => '_$s = $s').join(', ')}\n',
          newlineIndex: -1);
    } else {
      context.push(
          'import { ${helpers.map((s) => '$s as _$s').join(', ')} } from ${jsonEncode(context.options.runtimeModuleName)}\n',
          newlineIndex: -1);
    }
  }
  if (ast.imports.isNotEmpty) {
    _genImports(ast.imports, context);
    context.newline();
  }
  _genHoists(ast.hoists, context);
  context.newline();
  if (!inline) context.push('export ');
}

void _genFunctionPreamble(RootNode ast, CodegenContext context) {
  final helpers = ast.helpers.toList();
  final vueBinding = context.options.runtimeGlobalName;
  if (helpers.isNotEmpty) {
    if (context.options.prefixIdentifiers) {
      context.push(
          'const { ${helpers.map((s) => '$s: _$s').join(', ')} } = $vueBinding\n');
    } else {
      context.push('const _Vue = $vueBinding\n');
    }
  }
  _genHoists(ast.hoists, context);
  context.newline();
  context.push('return ');
}

extension on CodegenOptions {
  String get runtimeGlobalName => 'Vue';
}

void _genHoists(List<Object?> hoists, CodegenContext context) {
  if (hoists.isEmpty) return;
  context.pure = true;
  context.newline();
  for (var i = 0; i < hoists.length; i++) {
    final exp = hoists[i];
    if (exp != null) {
      context.push('const _hoisted_${i + 1} = ');
      genNode(exp, context);
      context.newline();
    }
  }
  context.pure = false;
}

void _genImports(List<Object?> importsOptions, CodegenContext context) {
  for (final imports in importsOptions) {
    if (imports is! Map) continue;
    context.push('import ');
    genNode(imports['exp'], context);
    context.push(" from '${imports['path']}'");
    context.newline();
  }
}
