// Port of @vue/compiler-dom: compile()/parse() option assembly.
// baseCompile with DOM parserOptions + DOMNodeTransforms/DOMDirectiveTransforms.
// 与 compile_template.dart（SFC doCompileTemplate 口径）的区别：
// 默认 mode:function、prefixIdentifiers:false、hoistStatic/cacheHandlers:false，
// 无 scopeId/slotted/hmr/asset-url 变换；错误按官方 defaultOnError 直接抛出。
// 未移植选项：ssr/inSSR/ssrCssVars、delimiters、自定义 nodeTransforms/
// directiveTransforms 注入、scopeId（error 50 路径）。
import 'template/codegen.dart';
import 'template/compile_template.dart';
import 'template/dom_options.dart';
import 'template/js_nodes.dart';
import 'template/tmpl_ast.dart';
import 'template/tmpl_error_messages.dart';
import 'template/tmpl_parser.dart';
import 'template/transform.dart';
import 'template/transform_context.dart';
import 'template/transforms/dom_transforms.dart';
import 'template/transforms/slot_outlet.dart';
import 'template/transforms/stringify_static.dart';
import 'template/transforms/track_scopes.dart';
import 'template/transforms/transform_element.dart';
import 'template/transforms/transform_expression.dart';
import 'template/transforms/transform_text.dart';
import 'template/transforms/v_for.dart';
import 'template/transforms/v_if.dart';
import 'template/transforms/v_model_core.dart';
import 'template/transforms/v_on_bind.dart';
import 'template/transforms/v_once_memo.dart';

/// compiler-dom CompilerOptions 的已支持子集。
final class DomCompileOptions {
  String filename = 'template.vue.html';
  String mode = 'function'; // 'function' | 'module'
  bool prefixIdentifiers = false;
  bool hoistStatic = false;
  bool cacheHandlers = false;
  String whitespace = 'condense';
  bool comments = true;
  bool isTS = false;
  bool sourceMap = false;
  bool Function(String tag)? isCustomElement;
  void Function(TmplCompileError e)? onError;
  void Function(TmplCompileError e)? onWarn;
}

/// @vue/compiler-dom compile(template, options)。
/// 默认选项与官方一致；错误默认抛出（官方 defaultOnError）。
TmplCompileResult compile(String template, [DomCompileOptions? options]) {
  final opt = options ?? DomCompileOptions();
  final prefix = opt.prefixIdentifiers || opt.mode == 'module';
  final errors = <TmplCompileError>[];
  final warnings = <TmplCompileError>[];
  if (!prefix && opt.cacheHandlers) {
    _raise(opt, TmplCompileError(49, tmplErrorMessage(49)), errors);
  }
  final ast = baseParse(template, _domParseOptions(opt, prefix, errors));
  transform(ast, _domTransformOptions(opt, prefix, errors, warnings));
  final gen = generate(ast, _domCodegenOptions(opt, prefix));
  return TmplCompileResult(gen.code, ast, errors, warnings,
      preamble: gen.preamble, map: gen.map);
}

/// @vue/compiler-dom parse(template, options)。
RootNode parse(String template, [DomCompileOptions? options]) {
  final opt = options ?? DomCompileOptions();
  return baseParse(
      template, _domParseOptions(opt, opt.prefixIdentifiers, []));
}

void _raise(DomCompileOptions opt, TmplCompileError e,
    List<TmplCompileError> errors) {
  final handler = opt.onError;
  if (handler == null) throw e;
  errors.add(e);
  handler(e);
}

TmplParserOptions _domParseOptions(
    DomCompileOptions opt, bool prefix, List<TmplCompileError> errors) {
  return domParserOptions(
    prefixIdentifiers: prefix,
    whitespace: opt.whitespace,
    comments: opt.comments,
    isCustomElement: opt.isCustomElement,
    onError: (e) => _raise(opt,
        TmplCompileError(e.code, e.message ?? tmplErrorMessage(e.code), e.loc),
        errors),
  );
}

TransformOptions _domTransformOptions(DomCompileOptions opt, bool prefix,
    List<TmplCompileError> errors, List<TmplCompileError> warnings) {
  void onError(TmplCompileError e) => _raise(opt, e, errors);
  void onWarn(TmplCompileError e) => _warn(opt, e, warnings);
  return TransformOptions()
    ..filename = opt.filename
    ..prefixIdentifiers = prefix
    ..hoistStatic = opt.hoistStatic
    ..cacheHandlers = opt.cacheHandlers
    ..isTS = opt.isTS
    ..nodeTransforms = _domNodeTransforms(prefix)
    ..directiveTransforms = _domDirectiveTransforms()
    ..transformHoist = stringifyStatic
    ..isBuiltInComponent = _domBuiltInComponent
    ..isCustomElement = opt.isCustomElement
    ..onError = onError
    ..onWarn = onWarn;
}

void _warn(DomCompileOptions opt, TmplCompileError e,
    List<TmplCompileError> warnings) {
  warnings.add(e);
  opt.onWarn?.call(e);
}

/// getBaseTransformPreset(prefixIdentifiers) + ignoreSideEffectTags +
/// DOMNodeTransforms（compile_template.dart 的 SFC 版另含 asset-url）。
List<NodeTransform> _domNodeTransforms(bool prefix) => [
      transformVBindShorthand,
      transformOnce,
      transformIf,
      transformMemo,
      transformFor,
      if (prefix) ...[trackVForSlotScopes, transformExpression],
      transformSlotOutlet,
      transformElement,
      trackSlotScopes,
      transformText,
      ignoreSideEffectTags,
      transformStyle,
      transformTransition,
      validateHtmlNesting,
    ];

/// DOMDirectiveTransforms（core on/bind/model 之上按 DOM 覆盖）。
Map<String, DirectiveTransform> _domDirectiveTransforms() {
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

/// compiler-dom parserOptions.isBuiltInComponent（helper 名为身份键）。
String? _domBuiltInComponent(String tag) {
  if (tag == 'Transition' || tag == 'transition') return hTransition;
  if (tag == 'TransitionGroup' || tag == 'transition-group') {
    return hTransitionGroup;
  }
  return null;
}

CodegenOptions _domCodegenOptions(DomCompileOptions opt, bool prefix) {
  return CodegenOptions()
    ..mode = opt.mode
    ..prefixIdentifiers = prefix
    ..filename = opt.filename
    ..isTS = opt.isTS
    ..sourceMap = opt.sourceMap;
}
