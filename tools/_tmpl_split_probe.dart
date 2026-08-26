// Scratch probe: split Dart template transform vs codegen on large_50,
// replicating compileTemplateSource's private option assembly exactly.
import 'dart:io';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/template/codegen.dart';
import 'package:vue_sfc_parser/template/compile_template.dart';
import 'package:vue_sfc_parser/template/dom_options.dart';
import 'package:vue_sfc_parser/template/js_nodes.dart';
import 'package:vue_sfc_parser/template/tmpl_ast.dart';
import 'package:vue_sfc_parser/template/tmpl_parser.dart';
import 'package:vue_sfc_parser/template/transform.dart';
import 'package:vue_sfc_parser/template/transform_context.dart';
import 'package:vue_sfc_parser/template/transforms/expression_cache.dart';
import 'package:vue_sfc_parser/template/transforms/asset_url.dart';
import 'package:vue_sfc_parser/template/transforms/dom_transforms.dart';
import 'package:vue_sfc_parser/template/transforms/slot_outlet.dart';
import 'package:vue_sfc_parser/template/transforms/stringify_static.dart';
import 'package:vue_sfc_parser/template/transforms/track_scopes.dart';
import 'package:vue_sfc_parser/template/transforms/transform_element.dart';
import 'package:vue_sfc_parser/template/transforms/transform_expression.dart';
import 'package:vue_sfc_parser/template/transforms/transform_text.dart';
import 'package:vue_sfc_parser/template/transforms/v_for.dart';
import 'package:vue_sfc_parser/template/transforms/v_if.dart';
import 'package:vue_sfc_parser/template/transforms/v_model_core.dart';
import 'package:vue_sfc_parser/template/transforms/v_on_bind.dart';
import 'package:vue_sfc_parser/template/transforms/v_once_memo.dart';
import 'package:vue_sfc_parser/ts_syntax/est_node.dart';
import 'package:vue_sfc_parser/ts_parser.dart';

String? _domBuiltInComponent(String tag) {
  if (tag == 'Transition' || tag == 'transition') return hTransition;
  if (tag == 'TransitionGroup' || tag == 'transition-group') {
    return hTransitionGroup;
  }
  return null;
}

TransformOptions _opts(List<TmplCompileError> errors, List<TmplCompileError> warns) {
  return TransformOptions()
    ..filename = './large_50.vue'
    ..prefixIdentifiers = true
    ..hoistStatic = true
    ..cacheHandlers = true
    ..hmr = true
    ..bindingMetadata = const {}
    ..inline = false
    ..isTS = false
    ..nodeTransforms = [
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
      ignoreSideEffectTags,
      transformStyle,
      transformTransition,
      validateHtmlNesting,
      transformAssetUrl,
      transformSrcset,
    ]
    ..directiveTransforms = {
      'on': transformOnDom,
      'bind': transformBindCore,
      'model': transformModelDom,
      'cloak': noopDirectiveTransform,
      'html': transformVHtml,
      'text': transformVText,
      'show': transformShow,
    }
    ..transformHoist = stringifyStatic
    ..isBuiltInComponent = _domBuiltInComponent
    ..scopeId = null
    ..slotted = true
    ..ssrCssVars = ''
    ..onError = errors.add
    ..onWarn = warns.add;
}

CodegenOptions _genOpts() {
  return CodegenOptions()
    ..sourceMap = false
    ..mode = 'module'
    ..prefixIdentifiers = true
    ..filename = './large_50.vue'
    ..scopeId = null
    ..bindingMetadata = const {}
    ..inline = false
    ..isTS = false;
}

void _fillExprCache(TmplNode ast, TransformOptions opts) {
  final mode = exprBatchMode;
  if (mode == 'off') return;
  final sources = collectExpressionSources(ast);
  if (sources.length < 8) return;
  final cache = <String, AstNode>{};
  if (mode == 'ffi' || mode == 'bin') {
    fillExpressionCacheFfi(cache, sources, binary: mode == 'bin');
  } else if (mode == 'concat') {
    fillExpressionCacheConcat(cache, sources);
  }
  if (cache.isNotEmpty) opts.exprCache = cache;
}

void main() {
  final src = File('bench/corpus/large_50.vue').readAsStringSync();
  final d = SfcParser(src, filename: './large_50.vue').parse();
  final tpl = d.template!.content;
  const n = 60;
  int timeStage(void Function() f) {
    for (var i = 0; i < 5; i++) {
      f();
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      f();
    }
    return sw.elapsedMicroseconds ~/ n;
  }

  RootNode parse() => baseParse(
    tpl,
    domParserOptions(prefixIdentifiers: true, whitespace: 'condense'),
  );
  RootNode parsedAndTransformed() {
    final errors = <TmplCompileError>[];
    final warns = <TmplCompileError>[];
    final ast = parse();
    final opts = _opts(errors, warns);
    _fillExprCache(ast, opts);
    transform(ast, opts);
    return ast;
  }

  final tParse = timeStage(() {
    parse();
  });
  final tTransform = timeStage(() {
    parsedAndTransformed();
  });
  final tAll = timeStage(() {
    generate(parsedAndTransformed(), _genOpts());
  });
  final tPublic = timeStage(() {
    compileTemplateSource(tpl, filename: './large_50.vue', id: 'data-v-x');
  });
  stdout.writeln(
    'baseParse=$tParse transform=${tTransform - tParse} codegen=${tAll - tTransform} '
    '(incl-expr-cache) sum=$tAll publicFull=$tPublic (us/iter)',
  );
}
