import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/ts_ast.dart';
import 'package:vue_sfc_parser/ts_parser.dart';
import 'package:vue_sfc_parser/sfc_error.dart';

final class ScriptCodegen {
  static String generate({required SetupResult result}) {
    final buf = StringBuffer();
    final src = result.source;
    final ast = result.rootAst;

    final vueAliasImports = <String>[]; // e.g. _useSlots, _useModel
    final userImports = _collectImportLines(ast, src);
    // collected user imports by source used below for runtime injection
    final importsBySource = _collectImportsBySource(ast, src);
    final vueImportedNames = importsBySource['vue'] ?? <String>{};
    final declNames = _collectDeclaredNames(ast, src);

    final macro = _analyzeMacros(result.compilation, src, ast);

    _validateUsage(
      rootAst: ast,
      unit: result.compilation,
      src: src,
      filename: result.filename,
    );

    // do not alias useSlots; inject via runtime imports based on actual usage
    if (_hasDefineModel(result.compilation)) {
      vueAliasImports.add('useModel as _useModel');
    }
    // Pre-compute model props/emits to decide whether to import mergeModels
    final preModelCombined = _collectModelCombinedEntries(
      result.compilation,
      src,
    );
    final preModelEmits = _collectModelEmitEvents(result.compilation);
    final needsMergeModels =
        preModelCombined.isNotEmpty || preModelEmits.isNotEmpty;
    if (needsMergeModels) {
      vueAliasImports.add('mergeModels as _mergeModels');
    }
    // Header imports
    final useDefineComponentHeader = _shouldUseDefineComponentHeader(
      result.compilation,
    );
    if (vueAliasImports.isNotEmpty) {
      buf.writeln('import {');
      for (var i = 0; i < vueAliasImports.length; i++) {
        buf.writeln('  ${vueAliasImports[i]},');
      }
      if (useDefineComponentHeader) {
        buf.writeln('  defineComponent as _defineComponent,');
      }
      buf.writeln('} from "vue";');
    } else if (useDefineComponentHeader) {
      buf.writeln('import { defineComponent as _defineComponent } from "vue";');
    }
    for (final line in userImports) {
      buf.writeln(_fmtImport(line));
    }
    // Inject missing runtime API imports based on actual usage
    final usedRuntime = _collectUsedRuntimeApis(
      ast,
      src,
      declNames,
      importsBySource,
    );
    final missingRuntime = <String>[];
    for (final r in usedRuntime) {
      if (!vueImportedNames.contains(r)) {
        missingRuntime.add(r);
      }
    }
    if (missingRuntime.isNotEmpty) {
      buf.writeln('import {');
      for (final r in missingRuntime) {
        buf.writeln('  ${r},');
      }
      buf.writeln('} from "vue";');
    }
    // print type aliases at top-level
    for (final c in ast.children) {
      if (c.type == 'type_alias_declaration') {
        buf.writeln(src.substring(c.startByte, c.endByte));
      }
    }
    buf.writeln('');

    // Component options start
    if (useDefineComponentHeader) {
      buf.writeln('export default /*@__PURE__*/ _defineComponent({');
    } else {
      buf.writeln('export default {');
    }

    // defineOptions spreads first
    for (final spread in macro.optionSpreads) {
      buf.writeln('  ...${_normalizeObjectText(spread)},');
    }

    // omit __name to match official when defineOptions provides name

    // props (use _mergeModels when model exists)
    final modelCombined = preModelCombined;
    final stdPropsInner = _stripBraces(macro.propsOptionText);
    if (modelCombined.isNotEmpty) {
      buf.writeln('  props: /*@__PURE__*/ _mergeModels({');
      if (stdPropsInner != null && stdPropsInner.trim().isNotEmpty) {
        buf.writeln('    ${stdPropsInner.trim()}');
      }
      buf.writeln('  }, {');
      for (final e in modelCombined) {
        buf.writeln('    ${e},');
      }
      buf.writeln('  }),');
    } else if (macro.propsOptionText != null) {
      buf.writeln('  props: ${macro.propsOptionText},');
    }

    // emits (use _mergeModels to combine events)
    final modelEmits = preModelEmits;
    final stdEmits = macro.emitsOptionText;
    if (modelEmits.isNotEmpty) {
      final left = (stdEmits != null && stdEmits.trim().startsWith('['))
          ? stdEmits.trim()
          : (stdEmits == null ? '[]' : stdEmits.trim());
      final right = '[${modelEmits.join(', ')}]';
      buf.writeln('  emits: /*@__PURE__*/ _mergeModels(${left}, ${right}),');
    } else if (stdEmits != null) {
      buf.writeln('  emits: $stdEmits,');
    }

    // setup signature
    final hasProps = macro.propsOptionText != null;
    final needsEmit = macro.emitsOptionText != null;
    final setupParams = StringBuffer();
    setupParams.write('__props');
    if (hasProps) setupParams.write(': any');
    final ctxParams = <String>['expose: __expose'];
    if (needsEmit) ctxParams.add('emit: __emit');
    buf.writeln(
      '  setup(${setupParams.toString()}, { ${ctxParams.join(', ')} }) {',
    );
    if (!macro.hasDefineExpose) {
      buf.writeln('    __expose();');
    }
    buf.writeln('');

    // Setup body statements: derive from AST, transform macros
    final stmts = _collectTopLevelStatements(ast);
    final skipReturn = <String>{};
    for (final s in stmts) {
      final rendered = _renderStatement(s, src, macro, declNames);
      if (rendered == null) continue;
      if (rendered.semicolon) {
        buf.writeln(_fmtStmt(rendered.text));
      } else {
        buf.writeln('    ${rendered.text}');
      }
      for (final n in rendered.skipNames) {
        skipReturn.add(n);
      }
    }
    buf.writeln('');

    // __returned__: use declaration order, then append macro bindings, excluding macro-only bindings
    final ordered = <String>[];
    final toSkip = {...skipReturn, ...macro.skipBindings};
    for (final n in declNames) {
      if (toSkip.contains(n)) continue;
      if (!ordered.contains(n)) ordered.add(n);
    }
    for (final n in macro.returnBindings) {
      if (toSkip.contains(n)) continue;
      if (!ordered.contains(n)) ordered.add(n);
    }

    buf.writeln('    const __returned__ = { ${ordered.join(', ')} };');
    buf.writeln('    Object.defineProperty(__returned__, "__isScriptSetup", {');
    buf.writeln('      enumerable: false,');
    buf.writeln('      value: true,');
    buf.writeln('    });');
    buf.writeln('    return __returned__;');
    buf.writeln('  },');
    if (useDefineComponentHeader) {
      buf.writeln('});');
    } else {
      buf.writeln('};');
    }

    return buf.toString();
  }
}

class _MacroIR {
  String? propsOptionText;
  String? emitsOptionText;
  final List<String> optionSpreads;
  final List<String> returnBindings;
  bool needsUseSlots;
  bool hasDefineExpose = false;
  bool hasDefineModel = false;
  bool hasDefineModelGeneric = false;
  final Set<String> skipBindings;
  _MacroIR({
    this.propsOptionText,
    this.emitsOptionText,
    this.optionSpreads = const [],
    this.returnBindings = const [],
    this.needsUseSlots = false,
    this.skipBindings = const {},
  });
}

_MacroIR _analyzeMacros(CompilationUnit unit, String src, AstNode ast) {
  String? propsText;
  String? emitsText;
  final spreads = <String>[];
  final returns = <String>[];
  var needsUseSlots = false;
  final skip = <String>{};

  // Pass 1: collect defaults from withDefaults(defineProps(...), { ... })
  final defaultMap = <String, String>{};
  for (final st in unit.statements) {
    final expr = st.expression;
    if (expr is FunctionCallExpression &&
        expr.methodName.name == 'withDefaults') {
      // second arg object as defaults
      final defaultsObj = _firstObjectArg(expr);
      if (defaultsObj != null) {
        for (final e in defaultsObj.elements) {
          defaultMap[e.keyText] = _normalizeObjectText(e.value.text);
        }
      }
    }
  }

  // Pass 2: analyze macros from statements only
  for (final st in unit.statements) {
    final expr = st.expression;
    if (expr is! FunctionCallExpression) continue;
    final name = expr.methodName.name;
    switch (name) {
      case 'defineProps':
        {
          final runtimeObj = _firstObjectArg(expr);
          if (runtimeObj != null) {
            propsText = _fmtInlinePropsObject(runtimeObj);
          } else if (expr.typeArgumentProps.isNotEmpty) {
            propsText = _fmtPropsFromType(expr.typeArgumentProps, defaultMap);
          } else {
            propsText = '{}';
          }
          if (!returns.contains('props')) returns.add('props');
          skip.add('props');
          break;
        }
      case 'withDefaults':
        {
          // no direct return identifiers without source pattern; rely on props
          if (!returns.contains('props')) returns.add('props');
          break;
        }
      case 'defineEmits':
        {
          final arr = _firstArrayArg(expr);
          final obj = _firstObjectArg(expr);
          final typed = expr.typeArgumentText;
          if (arr != null) {
            emitsText = _fmtStringArray(arr);
          } else if (obj != null) {
            emitsText = _normalizeObjectText(obj.text);
          } else if (typed != null && typed.isNotEmpty) {
            final events = _eventsFromTypeArgs(typed);
            emitsText = events.isNotEmpty
                ? '[${events.map((e) => '"$e"').join(', ')}]'
                : '[]';
          }
          if (!returns.contains('emit')) returns.add('emit');
          skip.add('emit');
          break;
        }
      case 'defineExpose':
        {
          // expose keys are not added to returned bindings
          break;
        }
      case 'defineSlots':
        {
          needsUseSlots = true;
          if (!returns.contains('slots')) returns.add('slots');
          break;
        }
      case 'defineOptions':
        {
          final obj = _firstObjectArg(expr);
          if (obj != null) spreads.add(_normalizeObjectText(obj.text));
          break;
        }
      case 'defineModel':
        {
          break;
        }
    }
  }

  // Fallback: scan full AST for defineEmits type arguments
  if (emitsText == null || (emitsText?.isEmpty ?? false)) {
    void walk(AstNode n) {
      if (n.type == 'call_expression') {
        final id = _findChildByType(n, 'identifier');
        if (id != null) {
          final name = src.substring(id.startByte, id.endByte);
          if (name == 'defineEmits') {
            final typeArgs = _findChildByType(n, 'type_arguments');
            if (typeArgs != null) {
              final raw = src.substring(typeArgs.startByte, typeArgs.endByte);
              final events = _eventsFromTypeArgs(raw);
              if (events.isNotEmpty) {
                emitsText = '[${events.map((e) => '"$e"').join(', ')}]';
              }
            }
          }
        }
      }
      for (final c in n.children) walk(c);
    }
    walk(ast);
  }

  if (emitsText == null || (emitsText?.isEmpty ?? false)) {
    final gm = RegExp('defineEmits\s*<([\s\S]*?)>').firstMatch(src);
    if (gm != null) {
      final raw = gm.group(1)!;
      var events = _eventsFromTypeArgs(raw);
      if (events.isEmpty) {
        final ident = raw.trim();
        if (RegExp(r'^[A-Za-z_$]\w*$').hasMatch(ident)) {
          final aliasBody = _resolveTypeAliasBody(ast, src, ident);
          if (aliasBody != null) {
            events = _eventsFromTypeArgs(aliasBody);
          }
        }
      }
      if (events.isNotEmpty) {
        emitsText = '[${events.map((e) => '"$e"').join(', ')}]';
      }
    }
  }

  final ir = _MacroIR(
    propsOptionText: propsText,
    emitsOptionText: emitsText,
    optionSpreads: spreads,
    returnBindings: returns,
    needsUseSlots: needsUseSlots,
    skipBindings: skip,
  );
  for (final st in unit.statements) {
    final expr = st.expression;
    if (expr is FunctionCallExpression &&
        expr.methodName.name == 'defineExpose') {
      ir.hasDefineExpose = true;
      break;
    }
  }
  for (final st in unit.statements) {
    final expr = st.expression;
    if (expr is FunctionCallExpression &&
        expr.methodName.name == 'defineModel') {
      ir.hasDefineModel = true;
      ir.hasDefineModelGeneric =
          (expr.typeArgumentText != null && expr.typeArgumentText!.isNotEmpty);
    }
  }
  return ir;
}

class _RenderedStmt {
  final String text;
  final bool semicolon;
  final List<String> names;
  final List<String> skipNames;
  _RenderedStmt(
    this.text, {
    this.semicolon = true,
    this.names = const [],
    this.skipNames = const [],
  });
}

List<AstNode> _collectTopLevelStatements(AstNode root) {
  final out = <AstNode>[];
  for (final c in root.children) {
    if (c.type == 'import_declaration') continue;
    if (c.type == 'type_alias_declaration') continue;
    out.add(c);
  }
  return out;
}

_RenderedStmt? _renderStatement(
  AstNode stmt,
  String src,
  _MacroIR ir,
  List<String> declNames,
) {
  // Transform macro-related statements; otherwise preserve original
  switch (stmt.type) {
    case 'lexical_declaration':
    case 'variable_declaration':
      return _renderVariableDeclaration(stmt, src);
    case 'expression_statement':
      final call = _findChildByType(stmt, 'call_expression');
      if (call != null) {
        final ident = _findChildByType(call, 'identifier');
        final name = ident == null
            ? ''
            : src.substring(ident.startByte, ident.endByte);
        final rawStmt = src.substring(stmt.startByte, stmt.endByte).trim();
        if (rawStmt.startsWith('import ') || rawStmt.startsWith('type ')) {
          return null;
        }
        if (name == 'defineOptions') {
          return null;
        }
        if (name == 'defineSlots') {
          // avoid duplicate when slots already declared
          if (declNames.contains('slots')) return null;
          return _RenderedStmt('const slots = useSlots()');
        }
        if (name == 'defineExpose') {
          final args = _findChildByType(call, 'arguments');
          if (args != null) {
            final argsText = src.substring(args.startByte, args.endByte);
            return _RenderedStmt('__expose${_normalizeObjectText(argsText)}');
          }
        }
      }
      return _RenderedStmt(src.substring(stmt.startByte, stmt.endByte));
    case 'function_declaration':
    case 'class_declaration':
      return _RenderedStmt(
        src.substring(stmt.startByte, stmt.endByte),
        semicolon: false,
      );
    default:
      final rawStmt = src.substring(stmt.startByte, stmt.endByte).trim();
      if (rawStmt.startsWith('import ') || rawStmt.startsWith('type ')) {
        return null;
      }
      return _RenderedStmt(src.substring(stmt.startByte, stmt.endByte));
  }
}

_RenderedStmt? _renderVariableDeclaration(AstNode decl, String src) {
  AstNode? declarator;
  for (final c in decl.children) {
    if (c.type == 'variable_declarator') {
      declarator = c;
      break;
    }
  }
  declarator ??= decl;

  AstNode? lhs;
  AstNode? rhs;
  for (final c in declarator.children) {
    if (lhs == null && (c.type == 'identifier' || c.type.endsWith('_pattern'))) {
      lhs = c;
    }
  }
  rhs = _findChildByType(declarator, 'call_expression');
  if (rhs == null || lhs == null) {
    return _RenderedStmt(src.substring(decl.startByte, decl.endByte));
  }
  final callee = _getCallCalleeName(rhs, src);
  final lhsText = src.substring(lhs.startByte, lhs.endByte);
  final lhsNames = _extractNamesFromLhs(lhs, src);

  if (callee == 'defineProps' || callee == 'withDefaults') {
    return _RenderedStmt('const $lhsText = __props', names: lhsNames, skipNames: lhsNames);
  }
  if (callee == 'defineEmits') {
    // ensure identifier lhs
    return _RenderedStmt('const $lhsText = __emit', names: lhsNames, skipNames: lhsNames);
  }
  if (callee == 'defineSlots') {
    return _RenderedStmt('const $lhsText = useSlots()', names: lhsNames);
  }
  if (callee == 'defineModel') {
    final typeArgs = _findChildByType(rhs, 'type_arguments');
    String? tsType;
    if (typeArgs != null) {
      var t = src.substring(typeArgs.startByte, typeArgs.endByte);
      t = t.replaceAll(RegExp(r'[<>]'), '').trim();
      tsType = t;
    }
    final args = _findChildByType(rhs, 'arguments');
    String nameArg = '"modelValue"';
    String? optionsArg;
    if (args != null) {
      // find first string child as name
      for (final a in args.children) {
        if (a.type == 'string' || a.type == 'template_string') {
          nameArg = src.substring(a.startByte, a.endByte);
          break;
        }
      }
      // find second object child as options
      int objCount = 0;
      for (final a in args.children) {
        if (a.type == 'object') {
          objCount++;
          if (objCount >= 2) {
            optionsArg = src.substring(a.startByte, a.endByte);
            break;
          }
        }
      }
    }
    final typeGeneric = tsType != null && tsType.isNotEmpty ? '<$tsType>' : '';
    final callText = optionsArg == null
        ? '_useModel$typeGeneric(__props, $nameArg)'
        : '_useModel$typeGeneric(__props, $nameArg, ${_normalizeObjectText(optionsArg)})';
    return _RenderedStmt('const $lhsText = $callText', names: lhsNames);
  }
  // default: preserve
  return _RenderedStmt(src.substring(decl.startByte, decl.endByte), names: lhsNames);
}

List<String> _extractNamesFromLhs(AstNode lhs, String src) {
  final out = <String>[];
  if (lhs.type == 'identifier') {
    out.add(src.substring(lhs.startByte, lhs.endByte));
    return out;
  }
  if (lhs.type.endsWith('_pattern')) {
    for (final sp in lhs.children) {
      if (sp.type == 'identifier' || sp.type == 'shorthand_property_identifier') {
        out.add(src.substring(sp.startByte, sp.endByte));
      }
    }
  }
  return out;
}

AstNode? _findChildByType(AstNode n, String type) {
  for (final c in n.children) {
    if (c.type == type) return c;
    final r = _findChildByType(c, type);
    if (r != null) return r;
  }
  return null;
}

String _getCallCalleeName(AstNode call, String src) {
  // prefer immediate identifier child
  for (final c in call.children) {
    if (c.type == 'identifier') {
      return src.substring(c.startByte, c.endByte);
    }
    if (c.type == 'member_expression') {
      for (final mc in c.children) {
        if (mc.type == 'identifier') {
          return src.substring(mc.startByte, mc.endByte);
        }
      }
    }
  }
  final ident = _findChildByType(call, 'identifier');
  return ident == null ? '' : src.substring(ident.startByte, ident.endByte);
}

Set<String> _collectUsedRuntimeApis(
  AstNode root,
  String src,
  List<String> declNames,
  Map<String, Set<String>> importsBySource,
) {
  final out = <String>{};
  final allImported = <String>{};
  for (final v in importsBySource.values) {
    allImported.addAll(v);
  }
  const macroNames = {
    'defineOptions',
    'withDefaults',
    'defineProps',
    'defineEmits',
    'defineModel',
    'defineSlots',
    'defineExpose',
  };
  void walk(AstNode n) {
    if (n.type == 'call_expression') {
      final id = _findChildByType(n, 'identifier');
      if (id != null) {
        final name = src.substring(id.startByte, id.endByte);
        if (macroNames.contains(name)) {
          // skip compile-time macros
        } else if (declNames.contains(name)) {
          // local declaration; skip
        } else if ((importsBySource['vue'] ?? {}).contains(name)) {
          out.add(name);
        } else if (!allImported.contains(name)) {
          // not imported from any module and not declared; treat as vue runtime to inject
          out.add(name);
        }
      }
    }
    for (final c in n.children) walk(c);
  }
  walk(root);
  return out;
}

Map<String, Set<String>> _collectImportsBySource(AstNode root, String src) {
  final out = <String, Set<String>>{};
  void walk(AstNode n) {
    if (n.type == 'import_declaration') {
      final text = src.substring(n.startByte, n.endByte);
      final m = RegExp("from\\s+[\"']([^\"']+)[\"']").firstMatch(text);
      final source = m?.group(1) ?? '';
      final names = <String>{};
      final brace = RegExp(r'\{([^}]*)\}').firstMatch(text);
      if (brace != null) {
        final inner = brace.group(1)!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        for (final i in inner) {
          final name = i.split(' as ')[0].trim();
          if (name.isNotEmpty) names.add(name);
        }
      }
      out[source] = (out[source] ?? <String>{})..addAll(names);
      return;
    }
    for (final c in n.children) walk(c);
  }
  walk(root);
  return out;
}

void _validateUsage({
  required AstNode rootAst,
  required CompilationUnit unit,
  required String src,
  required String filename,
}) {
  // ES module exports are not allowed in <script setup>
  int exportStart = -1;
  int exportEnd = -1;
  void scan(AstNode n) {
    if (n.type.contains('export')) {
      exportStart = n.startByte;
      exportEnd = n.endByte;
      return;
    }
    for (final c in n.children) scan(c);
  }

  scan(rootAst);
  if (exportStart >= 0) {
    throw SfcCompileError(
      filename: filename,
      reason: '<script setup> cannot contain ES module exports.',
      line1: '1 | <script setup lang="ts">',
      caret1: '| ^',
      line2: '2 | export ...',
      caret2: '| ^^^^^^^^^',
      line3: '3 | </script>',
      locStart: exportStart,
      locEnd: exportEnd,
    );
  }

  // defineSlots() cannot accept runtime arguments
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineSlots') {
      if (e.argumentList.arguments.isNotEmpty) {
        final lines = _renderErrorThreeLines(src, 'defineSlots({})');
        throw SfcCompileError(
          filename: filename,
          reason: 'defineSlots() cannot accept arguments',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
    }
  }

  // withDefaults must wrap defineProps with type arguments
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'withDefaults') {
      if (e.argumentList.arguments.isEmpty) {
        final lines = _renderErrorThreeLines(
          src,
          'withDefaults(defineProps(), {})',
        );
        throw SfcCompileError(
          filename: filename,
          reason: 'withDefaults() expects defineProps() as first argument',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
      final first = e.argumentList.arguments.first;
      if (first is! FunctionCallExpression ||
          first.methodName.name != 'defineProps') {
        throw ScriptError(
          message:
              'Vue Compile Error: [@vue/compiler-sfc] withDefaults() expects defineProps() as first argument',
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
      if (first.typeArgumentProps.isEmpty) {
        final lines = _renderErrorThreeLines(
          src,
          'withDefaults(defineProps({}), {})',
        );
        throw SfcCompileError(
          filename: filename,
          reason: 'withDefaults() only works with typed defineProps()',
          line1: lines[0],
          caret1: lines[1],
          line2: lines[2],
          caret2: lines[3],
          line3: lines[4],
          locStart: st.startByte,
          locEnd: st.endByte,
        );
      }
    }
  }
}

List<String> _renderErrorThreeLines(String src, String focusLine) {
  final l1 = '1 | <script setup lang="ts">';
  final c1 = '| ^';
  String line2 = '2 | ' + focusLine;
  String c2 = '| ' + '^' * focusLine.length;
  final l3 = '3 | </script>';
  return [l1, c1, line2, c2, l3];
}

List<String> _collectImportLines(AstNode root, String src) {
  final out = <String>[];
  void walk(AstNode n) {
    if (n.type == 'import_declaration') {
      out.add(_fmtImport(src.substring(n.startByte, n.endByte)));
      return;
    }
    for (final c in n.children) walk(c);
  }

  walk(root);
  return out;
}

List<String> _collectImportedNames(List<String> importLines) {
  final out = <String>[];
  for (final l in importLines) {
    final brace = RegExp(r'\{([^}]*)\}').firstMatch(l);
    if (brace != null) {
      final inner = brace
          .group(1)!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final i in inner) {
        final name = i.split(' as ')[0].trim();
        if (name.isNotEmpty && !out.contains(name)) out.add(name);
      }
    }
    final def = RegExp(r'^\s*import\s+([A-Za-z_$][\w$]*)\s+from').firstMatch(l);
    if (def != null) {
      final name = def.group(1)!;
      if (!out.contains(name)) out.add(name);
    }
  }
  return out;
}

List<String> _collectDeclaredNames(AstNode root, String src) {
  final out = <String>[];
  for (final n in root.children) {
    if (n.type == 'function_declaration' || n.type == 'class_declaration') {
      for (final c in n.children) {
        if (c.type == 'identifier') {
          final name = src.substring(c.startByte, c.endByte);
          if (!out.contains(name)) out.add(name);
        }
      }
    }
    if (n.type == 'lexical_declaration' || n.type == 'variable_declaration') {
      for (final c in n.children) {
        if (c.type == 'variable_declarator') {
          for (final p in c.children) {
            if (p.type == 'identifier') {
              final name = src.substring(p.startByte, p.endByte);
              if (!out.contains(name)) out.add(name);
            } else if (p.type.endsWith('_pattern')) {
              for (final sp in p.children) {
                if (sp.type == 'identifier' ||
                    sp.type == 'shorthand_property_identifier') {
                  final name = src.substring(sp.startByte, sp.endByte);
                  if (!out.contains(name)) out.add(name);
                }
              }
            }
          }
        }
      }
    }
  }
  return out;
}

SetOrMapLiteral? _firstObjectArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is SetOrMapLiteral) return a;
  }
  return null;
}

ListLiteral? _firstArrayArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is ListLiteral) return a;
  }
  return null;
}

String _fmtPropsFromType(
  List<PropSignature> props,
  Map<String, String> defaults,
) {
  final buf = StringBuffer();
  buf.writeln('{');
  for (var i = 0; i < props.length; i++) {
    final p = props[i];
    final types = _runtimeTypesFromTypeText(p.type ?? '');
    final typeText = types.length == 1 ? types[0] : '[${types.join(', ')}]';
    final required = p.required ? 'true' : 'false';
    final def = defaults.containsKey(p.name)
        ? ", default: ${defaults[p.name]!}"
        : '';
    buf.writeln('    ${p.name}: { type: $typeText, required: $required$def },');
  }
  buf.write('  }');
  return buf.toString();
}

String _fmtInlinePropsObject(SetOrMapLiteral obj) {
  // Keep as single-line when possible
  final text = _normalizeObjectText(obj.text);
  return text;
}

String? _firstStringArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is StringLiteral) return '"${a.stringValue}"';
  }
  return null;
}

List<String> _runtimeTypesFromTypeText(String t) {
  final parts = t
      .split('|')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  String mapType(String s) {
    if (RegExp(r'\w+\[\]').hasMatch(s)) return 'Array';
    switch (s) {
      case 'string':
        return 'String';
      case 'number':
        return 'Number';
      case 'boolean':
        return 'Boolean';
      case 'object':
        return 'Object';
      default:
        return 'Object';
    }
  }

  final mapped = parts.map(mapType).toList();
  // dedupe
  final out = <String>[];
  for (final m in mapped) {
    if (!out.contains(m)) out.add(m);
  }
  return out;
}

String _fmtStringArray(ListLiteral arr) {
  final items = arr.elements
      .whereType<StringLiteral>()
      .map((s) => '"${s.stringValue}"')
      .join(', ');
  return '[${items}]';
}

String _fmtImport(String line) {
  var t = line.trim();
  t = t.replaceAll("'", '"');
  if (!t.endsWith(';')) t = '$t;';
  return t;
}

String _fmtStmt(String line) {
  var t = line.trimRight();
  if (!t.endsWith(';')) t = '$t;';
  return '    $t';
}

String _normalizeObjectText(String text) {
  var t = text.trim();
  t = t.replaceAll("'", '"');
  return t;
}

Map<String, String> _extractSecondArgObject(String callLine) {
  final m = RegExp(
    r'withDefaults\s*\(\s*defineProps[^,]*,\s*(\{[\s\S]*\})\s*\)',
  ).firstMatch(callLine);
  if (m == null) return {};
  final obj = m.group(1)!;
  final out = <String, String>{};
  final pairs = RegExp(r'([A-Za-z_$][\w$]*)\s*:\s*([^,}]+)').allMatches(obj);
  for (final p in pairs) {
    final key = p.group(1)!.trim();
    final val = p.group(2)!.trim();
    out[key] = val;
  }
  return out;
}

List<String> _findDestructureIdentifiers(List<String> lines, String keyword) {
  final out = <String>[];
  for (final l in lines) {
    final t = l.trim();
    if (!t.contains(keyword)) continue;
    final m = RegExp(r'^(const|let|var)\s*\{([^}]*)\}\s*=').firstMatch(t);
    if (m != null) {
      final inner = m.group(2)!.trim();
      for (final part in inner.split(',')) {
        final name = part.trim().split(':')[0].trim();
        if (name.isNotEmpty && !out.contains(name)) out.add(name);
      }
    }
  }
  return out;
}

bool _hasDefineModel(CompilationUnit unit) {
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineModel')
      return true;
  }
  return false;
}

bool _shouldUseDefineComponentHeader(CompilationUnit unit) {
  bool hasModel = false;
  bool anyGeneric = false;
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineModel') {
      hasModel = true;
      if (e.typeArgumentText != null && e.typeArgumentText!.isNotEmpty)
        anyGeneric = true;
    }
  }
  if (hasModel && !anyGeneric) return false;
  return true;
}

List<String> _collectModelPropsEntries(CompilationUnit unit, String src) {
  final out = <String>[];
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    if (e.methodName.name != 'defineModel') continue;
    String name = _firstStringArg(e) ?? '"modelValue"';
    String typeText = 'Object';
    if (e.typeArgumentText != null && e.typeArgumentText!.isNotEmpty) {
      final tt = e.typeArgumentText!.replaceAll(RegExp(r'[<>]'), '');
      final types = _runtimeTypesFromTypeText(tt);
      typeText = types.isNotEmpty ? types.first : 'Object';
    } else {
      final obj = _firstObjectArg(e);
      if (obj != null) {
        for (final m in obj.elements) {
          if (m.keyText == 'type') {
            typeText = _normalizeObjectText(m.value.text);
          }
        }
      }
    }
    String spread = '';
    // first argument object carries extras like default/required/local
    SetOrMapLiteral? obj0;
    if (e.argumentList.arguments.isNotEmpty &&
        e.argumentList.arguments[0] is SetOrMapLiteral) {
      obj0 = e.argumentList.arguments[0] as SetOrMapLiteral;
    }
    if (obj0 != null) {
      final extras = <String>[];
      for (final m in obj0.elements) {
        if (m.keyText == 'type') continue;
        extras.add('${m.keyText}: ${_normalizeObjectText(m.value.text)}');
      }
      if (extras.isNotEmpty) {
        spread = ', ...{ ${extras.join(', ')} }';
      }
    }
    // if options (second arg) exists but no extras, ensure empty spread
    // merge second arg limited options into spread (default/required/local)
    if (e.argumentList.arguments.length >= 2) {
      final a2 = e.argumentList.arguments[1];
      if (a2 is SetOrMapLiteral) {
        final extras2 = <String>[];
        for (final m in a2.elements) {
          if (m.keyText == 'default' ||
              m.keyText == 'required' ||
              m.keyText == 'local') {
            extras2.add('${m.keyText}: ${_normalizeObjectText(m.value.text)}');
          }
        }
        if (extras2.isNotEmpty) {
          if (spread.isEmpty) {
            spread = ', ...{ ${extras2.join(', ')} }';
          } else {
            spread = spread.replaceFirst(' }', ', ${extras2.join(', ')} }');
          }
        } else if (spread.isEmpty) {
          spread = ', ...{ }';
        }
      }
    }
    out.add('${name}: { type: ${typeText}${spread} }');
  }
  return out;
}

List<String> _collectModelModifiersEntries(CompilationUnit unit, String src) {
  final out = <String>[];
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    if (e.methodName.name != 'defineModel') continue;
    final name = _firstStringArg(e) ?? '"modelValue"';
    final raw = name.replaceAll('"', '');
    final mod = raw == 'modelValue' ? 'modelModifiers' : '${raw}Modifiers';
    out.add('"${mod}": {}');
  }
  return out;
}

List<String> _collectModelCombinedEntries(CompilationUnit unit, String src) {
  final out = <String>[];
  final props = _collectModelPropsEntries(unit, src);
  final mods = _collectModelModifiersEntries(unit, src);
  // Build in the order of defineModel statements
  int pi = 0, mi = 0;
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    if (e.methodName.name != 'defineModel') continue;
    if (pi < props.length) out.add(props[pi++]);
    if (mi < mods.length) out.add(mods[mi++]);
  }
  return out;
}

List<String> _collectModelEmitEvents(CompilationUnit unit) {
  final out = <String>[];
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    if (e.methodName.name != 'defineModel') continue;
    final name = _firstStringArg(e) ?? '"modelValue"';
    final ev = '"update:${name.replaceAll('"', '')}"';
    out.add(ev);
  }
  return out;
}

String? _stripBraces(String? obj) {
  if (obj == null) return null;
  final t = obj.trim();
  if (t.startsWith('{') && t.endsWith('}')) {
    return t.substring(1, t.length - 1);
  }
  return obj;
}

List<String> _eventsFromTypeArgs(String raw) {
  final out = <String>[];
  final re = RegExp('\\(\\s*[A-Za-z_\$]\\w*\\s*:\\s*[\'\"]([^\'\"]+)[\'\"]');
  for (final m in re.allMatches(raw)) {
    out.add(m.group(1)!);
  }
  return out;
}
String? _resolveTypeAliasBody(AstNode root, String src, String ident) {
  String? found;
  void walk(AstNode n) {
    if (n.type == 'type_alias_declaration') {
      final text = src.substring(n.startByte, n.endByte);
      final m = RegExp(r"^\\s*(export\\s+)?type\\s+" + ident + r"\\s*=\\s*([\\s\\S]+)$").firstMatch(text);
      if (m != null) {
        found = m.group(2);
        return;
      }
    }
    for (final c in n.children) {
      if (found != null) return;
      walk(c);
    }
  }
  walk(root);
  return found;
}
