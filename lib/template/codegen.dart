// Port of compiler-core codegen.ts: generate() + genNode* family.
// Sourcemap emission is not needed for output parity, so push() only appends.
import 'dart:convert';

import 'codegen_nodes_gen.dart';
import 'js_nodes.dart';
import 'shared_utils.dart';
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
  Map<String, String>? bindingMetadata;
}

final class CodegenContext {
  final CodegenOptions options;
  final String source;
  final StringBuffer _buf = StringBuffer();
  int indentLevel = 0;
  bool pure = false;

  CodegenContext(RootNode ast, this.options) : source = _sourceOf(ast);

  static String _sourceOf(RootNode ast) => ast.loc.source;

  String get code => _buf.toString();

  void push(String code) => _buf.write(code);

  void indent() => _newline(++indentLevel);

  void deindent([bool withoutNewLine = false]) {
    if (withoutNewLine) {
      --indentLevel;
    } else {
      _newline(--indentLevel);
    }
  }

  void newline() => _newline(indentLevel);

  void _newline(int n) => push('\n${'  ' * n}');

  String helper(String name) => '_$name';
}

final class CodegenResult {
  final RootNode ast;
  final String code;
  final String preamble;
  CodegenResult(this.ast, this.code, this.preamble);
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
      isSetupInlined ? preambleContext.code : '');
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
    context.push('\n');
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
          'import { ${helpers.join(', ')} } from ${jsonEncode(context.options.runtimeModuleName)}\n');
      context.push(
          '\n// Binding optimization for webpack code-split\nconst ${helpers.map((s) => '_$s = $s').join(', ')}\n');
    } else {
      context.push(
          'import { ${helpers.map((s) => '$s as _$s').join(', ')} } from ${jsonEncode(context.options.runtimeModuleName)}\n');
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
