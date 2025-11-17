import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'dart:convert';
import 'package:vue_sfc_parser/ts_ast.dart';
import 'package:vue_sfc_parser/ts_parser.dart';
import 'package:vue_sfc_parser/validate_usage.dart';

final class ScriptCodegen {
  static String generate({required SetupResult setup}) {
    final buf = StringBuffer();
    final src = setup.source;
    final ast = setup.rootAst;

    final vueAliasImports = <String>[]; // e.g. _useSlots, _useModel
    final userImports = setup.setupImportLines ?? _collectImportLines(ast, src);
    final declNames = _collectDeclaredNames(ast, src);
    final macro = _analyzeMacros(setup.compilation, src, ast);

    validateUsage(
      rootAst: ast,
      unit: setup.compilation,
      src: src,
      filename: setup.filename,
    );

    // do not alias useSlots; inject via runtime imports based on actual usage
    if (_hasDefineModel(setup.compilation)) {
      vueAliasImports.add('useModel as _useModel');
    }
    // Pre-compute model props/emits to decide whether to import mergeModels
    final preModelCombined = _collectModelCombinedEntries(
      setup.compilation,
      src,
    );
    final preModelEmits = _collectModelEmitEvents(setup.compilation);
    final needsMergeModels =
        preModelCombined.isNotEmpty || preModelEmits.isNotEmpty;
    if (needsMergeModels) {
      vueAliasImports.add('mergeModels as _mergeModels');
    }
    // Header imports
    final useDefineComponentHeader = _shouldUseDefineComponentHeader(
      setup.compilation,
    );
    if (vueAliasImports.isNotEmpty) {
      final aliases = [...vueAliasImports];
      if (useDefineComponentHeader) {
        aliases.add('defineComponent as _defineComponent');
      }
      buf.writeln('import { ${aliases.join(', ')} } from "vue";');
    } else if (useDefineComponentHeader) {
      buf.writeln('import { defineComponent as _defineComponent } from "vue";');
    }
    final setupVueFromLines = _parseVueNamedFromLines(userImports);
    final setupVueFromSource = _parseVueNamedFromSource(src);
    final unionNames = <String>{...setupVueFromLines, ...setupVueFromSource};
    if (unionNames.isNotEmpty) {
      final ordered = (unionNames.toList());
      buf.writeln('import {');
      for (final r in ordered) {
        buf.writeln('  $r,');
      }
      buf.writeln('} from "vue";');
    }
    // Then user imports（仅输出非 vue 源的导入；setup 的 vue 导入由上方按使用输出）
    for (final line in userImports) {
      if (!RegExp("from\\s*['\\\"]vue['\\\"]").hasMatch(line)) {
        buf.writeln(_fmtImport(line));
      }
    }
    // Normal <script> imports (e.g., createApp, namespace imports)
    final normalImports = setup.normalScriptImportLines ?? const <String>[];
    for (final line in normalImports) {
      buf.writeln(_fmtImport(line));
    }
    // Always include namespace import for full vue access
    // print type aliases at top-level
    for (final c in ast.children) {
      if (c.type == 'type_alias_declaration') {
        buf.writeln(_slice(src, c.startByte, c.endByte));
      }
    }
    buf.writeln('');
    // Define __default__ from normal <script> default export
    // todo  此处处理逻辑保留， 其余的 normalSpread 逻辑不要
    final normalSpread = setup.normalScriptSpreadText;
    if (normalSpread != null && normalSpread.trim().isNotEmpty) {
      buf.writeln('const __default__ = ${_normalizeObjectText(normalSpread)};');
    }

    // Component options start
    if (useDefineComponentHeader) {
      buf.writeln('export default /*@__PURE__*/ _defineComponent({');
    } else {
      buf.writeln('export default {');
    }
    // Spread from normal <script> default export first
    if (normalSpread != null && normalSpread.trim().isNotEmpty) {
      buf.writeln('  ...__default__,');
    }
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
        buf.writeln(stdPropsInner.trim());
      }
      buf.writeln('},\n{');
      for (final e in modelCombined) {
        buf.writeln('    $e,');
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
      buf.writeln('emits: /*@__PURE__*/ _mergeModels($left, $right),');
    } else if (stdEmits != null) {
      buf.writeln('emits: $stdEmits,');
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
      'setup(${setupParams.toString()}, { ${ctxParams.join(', ')} }) {',
    );
    if (!macro.hasDefineExpose) {
      buf.writeln('__expose();');
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

    buf.writeln('    const __returned__ = {');
    for (final n in ordered) {
      buf.writeln('      $n,');
    }
    buf.writeln('    };');
    buf.writeln('    Object.defineProperty(__returned__, "__isScriptSetup", {');
    buf.writeln('      enumerable: false,');
    buf.writeln('      value: true,');
    buf.writeln('    });');
    buf.writeln('return __returned__;');
    buf.writeln('},');
    if (useDefineComponentHeader) {
      buf.writeln('});');
    } else {
      buf.writeln('};');
    }

    final raw = buf.toString();
    final normalized = raw.split('\n').map((l) => l.trimLeft()).join('\n');
    return normalized;
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
      final defaultsObj = firstObjectArg(expr);
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
          final runtimeObj = firstObjectArg(expr);
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
          final arr = firstArrayArg(expr);
          final obj = firstObjectArg(expr);
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
          final obj = firstObjectArg(expr);
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
  if (emitsText == null || (emitsText.isEmpty)) {
    void walk(AstNode n) {
      if (n.type == 'call_expression') {
        final id = _findChildByType(n, 'identifier');
        if (id != null) {
          final name = slice(src, id.startByte, id.endByte);
          if (name == 'defineEmits') {
            final typeArgs = _findChildByType(n, 'type_arguments');
            if (typeArgs != null) {
              final raw = slice(src, typeArgs.startByte, typeArgs.endByte);
              final events = _eventsFromTypeArgs(raw);
              if (events.isNotEmpty) {
                emitsText = '[${events.map((e) => '"$e"').join(', ')}]';
              }
            }
          }
        }
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(ast);
  }

  if (emitsText == null || (emitsText?.isEmpty ?? false)) {
    // ignore: unnecessary_string_escapes
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
    // ignore: unused_element_parameter
    this.skipNames = const [],
  });
}

List<AstNode> _collectTopLevelStatements(AstNode root) {
  final out = <AstNode>[];
  for (final c in root.children) {
    if (c.type == 'import_declaration') continue;
    if (c.type == 'type_alias_declaration') continue;
    if (c.type.contains('export')) continue;
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
            : slice(src, ident.startByte, ident.endByte);
        final rawStmt = slice(src, stmt.startByte, stmt.endByte).trim();
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
            final argsText = slice(src, args.startByte, args.endByte);
            return _RenderedStmt('__expose${_normalizeObjectText(argsText)}');
          }
        }
      }
      return _RenderedStmt(slice(src, stmt.startByte, stmt.endByte));
    case 'function_declaration':
    case 'class_declaration':
      return _RenderedStmt(
        slice(src, stmt.startByte, stmt.endByte),
        semicolon: false,
      );
    default:
      final rawStmt = slice(src, stmt.startByte, stmt.endByte).trim();
      if (rawStmt.startsWith('import ') || rawStmt.startsWith('type ')) {
        return null;
      }
      return _RenderedStmt(slice(src, stmt.startByte, stmt.endByte));
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
    if (lhs == null &&
        (c.type == 'identifier' || c.type.endsWith('_pattern'))) {
      lhs = c;
    }
  }
  rhs = _findChildByType(declarator, 'call_expression');
  if (rhs == null || lhs == null) {
    return _RenderedStmt(slice(src, decl.startByte, decl.endByte));
  }
  final callee = _getCallCalleeName(rhs, src);
  final lhsText = slice(src, lhs.startByte, lhs.endByte);
  final lhsNames = _extractNamesFromLhs(lhs, src);

  if (callee == 'defineProps' || callee == 'withDefaults') {
    return _RenderedStmt('const $lhsText = __props', names: lhsNames);
  }
  if (callee == 'defineEmits') {
    // ensure identifier lhs
    return _RenderedStmt('const $lhsText = __emit', names: lhsNames);
  }
  if (callee == 'defineSlots') {
    return _RenderedStmt('const $lhsText = useSlots()', names: lhsNames);
  }
  if (callee == 'defineModel') {
    final typeArgs = _findChildByType(rhs, 'type_arguments');
    String? tsType;
    if (typeArgs != null) {
      var t = slice(src, typeArgs.startByte, typeArgs.endByte);
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
          nameArg = slice(src, a.startByte, a.endByte);
          break;
        }
      }
      // find second object child as options
      int objCount = 0;
      for (final a in args.children) {
        if (a.type == 'object') {
          objCount++;
          if (objCount >= 2) {
            optionsArg = slice(src, a.startByte, a.endByte);
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
  return _RenderedStmt(
    slice(src, decl.startByte, decl.endByte),
    names: lhsNames,
  );
}

List<String> _extractNamesFromLhs(AstNode lhs, String src) {
  final out = <String>[];
  if (lhs.type == 'identifier') {
    out.add(slice(src, lhs.startByte, lhs.endByte));
    return out;
  }
  if (lhs.type.endsWith('_pattern')) {
    for (final sp in lhs.children) {
      if (sp.type == 'identifier' ||
          sp.type == 'shorthand_property_identifier') {
        out.add(slice(src, sp.startByte, sp.endByte));
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
      return slice(src, c.startByte, c.endByte);
    }
    if (c.type == 'member_expression') {
      for (final mc in c.children) {
        if (mc.type == 'identifier') {
          return slice(src, mc.startByte, mc.endByte);
        }
      }
    }
  }
  final ident = _findChildByType(call, 'identifier');
  return ident == null ? '' : slice(src, ident.startByte, ident.endByte);
}

List<String> renderErrorThreeLines(String src, String focusLine) {
  final l1 = '1 | <script setup lang="ts">';
  final c1 = '| ^';
  String line2 = '2 | $focusLine';
  String c2 = '| ${'^' * focusLine.length}';
  final l3 = '3 | </script>';
  return [l1, c1, line2, c2, l3];
}

List<String> _collectImportLines(AstNode root, String src) {
  final out = <String>[];
  final re = RegExp(r'^\s*import[\s\S]*?;', multiLine: true);
  for (final m in re.allMatches(src)) {
    final t = (m.group(0) ?? '').trimRight();
    if (t.isEmpty) continue;
    out.add(_fmtImport(t));
  }
  return out;
}

List<String> _collectDeclaredNames(AstNode root, String src) {
  final out = <String>[];
  for (final n in root.children) {
    if (n.type == 'function_declaration' || n.type == 'class_declaration') {
      for (final c in n.children) {
        if (c.type == 'identifier') {
          final name = slice(src, c.startByte, c.endByte);
          if (!out.contains(name)) out.add(name);
        }
      }
    }
    if (n.type == 'lexical_declaration' || n.type == 'variable_declaration') {
      for (final c in n.children) {
        if (c.type == 'variable_declarator') {
          for (final p in c.children) {
            if (p.type == 'identifier') {
              final name = slice(src, p.startByte, p.endByte);
              if (!out.contains(name)) out.add(name);
            } else if (p.type.endsWith('_pattern')) {
              for (final sp in p.children) {
                if (sp.type == 'identifier' ||
                    sp.type == 'shorthand_property_identifier') {
                  final name = slice(src, sp.startByte, sp.endByte);
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

SetOrMapLiteral? firstObjectArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is SetOrMapLiteral) return a;
  }
  return null;
}

ListLiteral? firstArrayArg(FunctionCallExpression call) {
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

String? firstStringArg(FunctionCallExpression call) {
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
  return '[$items]';
}

String _fmtImport(String line) {
  var t = line.trim();
  t = t.replaceAll("'", '"');
  if (!t.endsWith(';')) t = '$t;';
  return t;
}

List<String> _parseVueNamedFromLines(List<String> lines) {
  final names = <String>{};
  for (final line in lines) {
    // 简单解析 vue 源的命名导入行
    if (!RegExp("from\\s*['\\\"]vue['\\\"]").hasMatch(line)) continue;
    final brace = RegExp(r'\{([^}]*)\}').firstMatch(line);
    if (brace != null) {
      final inner = brace.group(1)!;
      final parts = inner
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final p in parts) {
        final name = p.split(' as ')[0].trim();
        if (name.isNotEmpty) names.add(name);
      }
    }
  }
  return names.toList();
}

List<String> _parseVueNamedFromSource(String s) {
  final names = <String>{};
  // 简单解析源码内首个 vue 命名导入块
  final m = RegExp(
    "import\\s*\\{([\\s\\S]*?)\\}\\s*from\\s*['\\\"]vue['\\\"]",
    multiLine: true,
  ).firstMatch(s);
  if (m != null) {
    final inner = m.group(1) ?? '';
    final parts = inner
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final p in parts) {
      final name = p.split(' as ')[0].trim();
      if (name.isNotEmpty) names.add(name);
    }
  }
  return names.toList();
}

List<String> _orderRuntimeImports(List<String> names) {
  const preferredOrder = [
    'reactive',
    'computed',
    'onMounted',
    'provide',
    'inject',
    'nextTick',
    'defineAsyncComponent',
    'useSlots',
    'useAttrs',
  ];
  final orderMap = {
    for (var i = 0; i < preferredOrder.length; i++) preferredOrder[i]: i,
  };
  final sorted = [...names];
  sorted.sort((a, b) {
    final ia = orderMap[a];
    final ib = orderMap[b];
    if (ia != null && ib != null) return ia.compareTo(ib);
    if (ia != null) return -1;
    if (ib != null) return 1;
    return a.compareTo(b);
  });
  return sorted;
}

String _slice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final safeStart = startByte.clamp(0, bytes.length);
  final safeEnd = endByte.clamp(0, bytes.length);
  if (safeEnd <= safeStart) return '';
  return utf8.decode(bytes.sublist(safeStart, safeEnd));
}

String _fmtStmt(String line) {
  var t = line.trimRight();
  if (!t.endsWith(';')) t = '$t;';
  return t;
}

String _normalizeObjectText(String text) {
  var t = text.trim();
  t = t.replaceAll("'", '"');
  t = t.split('\n').map((l) => l.trimLeft()).join('\n');
  return t;
}

bool _hasDefineModel(CompilationUnit unit) {
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineModel') {
      return true;
    }
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
      if (e.typeArgumentText != null && e.typeArgumentText!.isNotEmpty) {
        anyGeneric = true;
      }
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
    String name = firstStringArg(e) ?? '"modelValue"';
    String typeText = 'Object';
    if (e.typeArgumentText != null && e.typeArgumentText!.isNotEmpty) {
      final tt = e.typeArgumentText!.replaceAll(RegExp(r'[<>]'), '');
      final types = _runtimeTypesFromTypeText(tt);
      typeText = types.isNotEmpty ? types.first : 'Object';
    } else {
      final obj = firstObjectArg(e);
      if (obj != null) {
        for (final m in obj.elements) {
          if (m.keyText == 'type') {
            typeText = _normalizeObjectText(m.value.text);
          }
        }
      }
    }
    String spread = '';
    String? inlineDefault;
    // first argument object carries extras like default/required/local
    SetOrMapLiteral? obj0;
    if (e.argumentList.arguments.isNotEmpty &&
        e.argumentList.arguments[0] is SetOrMapLiteral) {
      obj0 = e.argumentList.arguments[0] as SetOrMapLiteral;
    }
    // compute raw name once for decision-making
    final rawName = name.replaceAll('"', '');
    if (obj0 != null) {
      final extras = <String>[];
      for (final m in obj0.elements) {
        if (m.keyText == 'type') continue;
        final kv = '${m.keyText}: ${_normalizeObjectText(m.value.text)}';
        if (m.keyText == 'default' && rawName == 'modelValue') {
          inlineDefault = _normalizeObjectText(m.value.text);
          continue;
        }
        extras.add(kv);
      }
      if (extras.isNotEmpty) {
        spread = ', ...{ ${extras.join(', ')} }';
      }
    }
    // merge second arg limited options into spread (default/required/local)
    if (e.argumentList.arguments.length >= 2) {
      final a2 = e.argumentList.arguments[1];
      if (a2 is SetOrMapLiteral) {
        final extras2 = <String>[];
        for (final m in a2.elements) {
          if (m.keyText == 'default' ||
              m.keyText == 'required' ||
              m.keyText == 'local') {
            if (m.keyText == 'default' && rawName == 'modelValue') {
              inlineDefault = _normalizeObjectText(m.value.text);
              continue;
            }
            extras2.add('${m.keyText}: ${_normalizeObjectText(m.value.text)}');
          }
        }
        if (extras2.isNotEmpty) {
          if (spread.isEmpty) {
            spread = ', ...{ ${extras2.join(', ')} }';
          } else {
            spread = spread.replaceFirst(' }', ', ${extras2.join(', ')} }');
          }
        }
      }
    }
    // inline default for canonical model name "modelValue"
    final defaultPart = (inlineDefault != null && rawName == 'modelValue')
        ? ', default: $inlineDefault'
        : '';
    final isIdent = RegExp(r'^[A-Za-z_$]\w*$').hasMatch(rawName);
    final keyText = isIdent ? rawName : name;
    out.add('$keyText: { type: $typeText$defaultPart$spread }');
  }
  return out;
}

List<String> _collectModelModifiersEntries(CompilationUnit unit, String src) {
  final out = <String>[];
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    if (e.methodName.name != 'defineModel') continue;
    final name = firstStringArg(e) ?? '"modelValue"';
    final raw = name.replaceAll('"', '');
    final mod = raw == 'modelValue' ? 'modelModifiers' : '${raw}Modifiers';
    out.add('$mod: {}');
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
    final name = firstStringArg(e) ?? '"modelValue"';
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
      final text = slice(src, n.startByte, n.endByte);
      // TODO 此处不要用正则，而是 ast
      final m = RegExp(
        r"^\\s*(export\\s+)?type\\s+" + ident + r"\\s*=\\s*([\\s\\S]+)$",
      ).firstMatch(text);
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

String slice(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  final safeStart = startByte.clamp(0, bytes.length);
  final safeEnd = endByte.clamp(0, bytes.length);
  if (safeEnd <= safeStart) return '';
  return utf8.decode(bytes.sublist(safeStart, safeEnd));
}
