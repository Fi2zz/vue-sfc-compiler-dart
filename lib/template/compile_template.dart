// Port of @vue/compiler-sfc compileTemplate/doCompileTemplate wired through
// compiler-dom compile() + compiler-core baseCompile() option assembly.
import 'codegen.dart';
import 'dart:io';
import 'dom_options.dart';
import 'js_nodes.dart';
import 'tmpl_ast.dart';
import 'tmpl_parser.dart';
import 'transform.dart';
import 'transform_context.dart';
import '../ts_parser.dart';
import 'transforms/expression_cache.dart';
import 'transforms/asset_url.dart';
import 'transforms/dom_transforms.dart';
import 'transforms/slot_outlet.dart';
import 'tmpl_error_messages.dart';
import 'transforms/stringify_static.dart';
import 'transforms/track_scopes.dart';
import 'transforms/transform_element.dart';
import 'transforms/transform_expression.dart';
import 'transforms/transform_text.dart';
import 'transforms/v_for.dart';
import 'transforms/v_if.dart';
import 'transforms/v_model_core.dart';
import 'transforms/v_on_bind.dart';
import 'transforms/v_once_memo.dart';

final class TmplCompileResult {
  final String code;
  final RootNode ast;
  final List<TmplCompileError> errors;
  final List<TmplCompileError> warnings;
  final String preamble;
  final Map<String, Object?>? map;
  TmplCompileResult(
    this.code,
    this.ast,
    this.errors,
    this.warnings, {
    this.preamble = '',
    this.map,
  });
}

/// Mirrors doCompileTemplate({source, filename, id, scoped, slotted}) with
/// compilerOptions = {} and default DOM compiler. stringifyStatic
/// (transformHoist) is deferred: it only alters output at >= 20 static text
/// nodes or >= 5 static elements per chunk, and passing null is output-equal
/// below those thresholds.
TmplCompileResult compileTemplateSource(
  String source, {
  required String filename,
  String id = '',
  bool scoped = false,
  bool? slotted,
  Map<String, String>? bindingMetadata,
  String whitespace = 'condense',
  bool inline = false,
  bool isTS = false,
  bool sourceMap = false,
}) {
  final errors = <TmplCompileError>[];
  final warnings = <TmplCompileError>[];
  final shortId = id.replaceFirst(RegExp('^data-v-'), '');
  final scopeId = scoped ? 'data-v-$shortId' : null;
  final ast = baseParse(
    source,
    _parseOptions(filename, scopeId, slotted, errors, warnings, whitespace),
  );
  final opts = _transformOptions(
    filename,
    scopeId,
    slotted,
    errors,
    warnings,
    bindingMetadata ?? const {},
    inline: inline,
    isTS: isTS,
  );
  _fillExprCache(ast, opts);
  transform(ast, opts);
  final gen = generate(
    ast,
    _codegenOptions(
      filename,
      scopeId,
      bindingMetadata,
      inline: inline,
      isTS: isTS,
      sourceMap: sourceMap,
    ),
  );
  return TmplCompileResult(
    gen.code,
    ast,
    errors,
    warnings,
    preamble: gen.preamble,
    map: gen.map,
  );
}

/// Batch-expression toggle for benchmarking/tuning (PERF_BENCHMARK.md):
/// TS_EXPR_BATCH=ffi|concat|off. Off by default. 'ffi' only engages when
/// enough expressions are collected to amortize the round-trip (measured
/// crossover ≈ 8); 'concat' measured net-negative on large tiers (rebase
/// allocation cost exceeds transport savings) and is kept for reference.
final String exprBatchMode = Platform.environment['TS_EXPR_BATCH'] ?? 'off';

const int _exprBatchMinSources = 8;

void _fillExprCache(TmplNode ast, TransformOptions opts) {
  final mode = exprBatchMode;
  if (mode == 'off') return;
  final sources = collectExpressionSources(ast);
  if (sources.length < _exprBatchMinSources) return;
  final cache = <String, AstNode>{};
  if (mode == 'ffi') {
    fillExpressionCacheFfi(cache, sources);
  } else if (mode == 'concat') {
    fillExpressionCacheConcat(cache, sources);
  }
  if (cache.isNotEmpty) opts.exprCache = cache;
}

TmplParserOptions _parseOptions(
  String filename,
  String? scopeId,
  bool? slotted,
  List<TmplCompileError> errors,
  List<TmplCompileError> warnings, [
  String whitespace = 'condense',
]) {
  return domParserOptions(
    prefixIdentifiers: true,
    whitespace: whitespace,
    onError: (e) => errors.add(
      TmplCompileError(e.code, e.message ?? tmplErrorMessage(e.code), e.loc),
    ),
  );
}

/// Mirror of official SFC parse behavior: the full-source parse surfaces
/// template-content parse errors (e.g. duplicate attributes) before
/// compileTemplate ever runs.
List<TmplCompileError> collectTemplateParseErrors(String content) {
  final errors = <TmplCompileError>[];
  baseParse(content, _parseOptions('', null, null, errors, []));
  return errors;
}

TransformOptions _transformOptions(
  String filename,
  String? scopeId,
  bool? slotted,
  List<TmplCompileError> errors,
  List<TmplCompileError> warnings,
  Map<String, String> bindingMetadata, {
  bool inline = false,
  bool isTS = false,
}) {
  return TransformOptions()
    ..filename = filename
    ..prefixIdentifiers = true
    ..hoistStatic = true
    ..cacheHandlers = true
    ..hmr = true
    ..bindingMetadata = bindingMetadata
    ..inline = inline
    ..isTS = isTS
    ..nodeTransforms = _nodeTransforms()
    ..directiveTransforms = _directiveTransforms()
    ..transformHoist = stringifyStatic
    ..isBuiltInComponent = _domBuiltInComponent
    ..scopeId = scopeId
    ..slotted = slotted ?? true
    ..ssrCssVars = ''
    ..onError = errors.add
    ..onWarn = warnings.add;
}

List<NodeTransform> _nodeTransforms() => [
  // getBaseTransformPreset(prefixIdentifiers: true)
  transformVBindShorthand,
  transformOnce,
  transformIf,
  transformMemo,
  transformFor,
  trackVForSlotScopes,
  transformExpression,
  transformSlotOutlet,
  transformElement,
  trackSlotScopes,
  transformText,
  // compiler-dom compile(): ignoreSideEffectTags + DOMNodeTransforms,
  // then doCompileTemplate's asset-url transforms.
  ignoreSideEffectTags,
  transformStyle,
  transformTransition,
  validateHtmlNesting,
  transformAssetUrl,
  transformSrcset,
];

Map<String, DirectiveTransform> _directiveTransforms() {
  // core preset, then DOM set overrides on/model (shared.extend order)
  final map = <String, DirectiveTransform>{
    'on': transformOnCore,
    'bind': transformBindCore,
    'model': transformModelCore,
  };
  map['cloak'] = noopDirectiveTransform;
  map['html'] = transformVHtml;
  map['text'] = transformVText;
  map['model'] = transformModelDom;
  map['on'] = transformOnDom;
  map['show'] = transformShow;
  return map;
}

/// compiler-dom isBuiltInComponent: Transition/TransitionGroup map to their
/// helper names (official returns Symbols; helper names are identity keys).
String? _domBuiltInComponent(String tag) {
  if (tag == 'Transition' || tag == 'transition') return hTransition;
  if (tag == 'TransitionGroup' || tag == 'transition-group') {
    return hTransitionGroup;
  }
  return null;
}

CodegenOptions _codegenOptions(
  String filename,
  String? scopeId,
  Map<String, String>? bindingMetadata, {
  bool inline = false,
  bool isTS = false,
  bool sourceMap = false,
}) {
  return CodegenOptions()
    ..sourceMap = sourceMap
    ..mode = 'module'
    ..prefixIdentifiers = true
    ..filename = filename
    ..scopeId = scopeId
    ..bindingMetadata = bindingMetadata
    ..inline = inline
    ..isTS = isTS;
}
