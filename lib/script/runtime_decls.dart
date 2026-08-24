// Port of genRuntimeProps / genRuntimeEmits / genModelProps output formats.
import 'package:vue_sfc_parser/ts_parser.dart';

import 'node_utils.dart';
import 'setup_context.dart';
import 'src_view.dart';
import 'type_infer.dart';

/// JS JSON.stringify for simple string keys.
String jsonString(String s) {
  final buf = StringBuffer('"');
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '"' || ch == '\\') {
      buf.write('\\$ch');
    } else if (rune < 0x20) {
      buf.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
    } else {
      buf.write(ch);
    }
  }
  buf.write('"');
  return buf.toString();
}

final _propNameEscapeRe = RegExp(r'''[ !"#$%&'()*+,./:;<=>?@\[\\\]^`{|}~\-]''');

String escapedPropName(String key) {
  return _propNameEscapeRe.hasMatch(key) ? jsonString(key) : key;
}

String _concatStrings(List<String?> parts) {
  return parts.whereType<String>().where((s) => s.isNotEmpty).join(', ');
}

final class _RuntimeProp {
  final String key;
  final bool required;
  final List<String> types;
  final bool skipCheck;

  _RuntimeProp(this.key, this.required, this.types, this.skipCheck);
}

List<_RuntimeProp> _propsFromType(SetupContext ctx) {
  final elements =
      resolveTypeElements(ctx.propsTypeDecl!, ctx.view, ctx.typeScope);
  final out = <_RuntimeProp>[];
  for (final key in elements.props.keys) {
    // 官方 genRuntimeProps：类型推导的 props 键登记进 bindingMetadata
    ctx.propsKeys.add(key);
    final e = elements.props[key]!;
    var types = e.method
        ? const ['Function']
        : e.typeNode == null
        ? const [unknownType]
        : inferRuntimeType(e.typeNode!, e.view, ctx.typeScope);
    var skipCheck = false;
    if (types.contains(unknownType)) {
      if (types.contains('Boolean') || types.contains('Function')) {
        types = types.where((t) => t != unknownType).toList();
        skipCheck = true;
      } else {
        types = const ['null'];
      }
    }
    out.add(_RuntimeProp(key, !e.optional, types, skipCheck));
  }
  return out;
}

/// Port of genDestructuredDefaultValue.
String? _destructuredDefault(
  SetupContext ctx,
  String key,
  List<String>? inferredType,
) {
  final binding = ctx.propsDestructuredBindings[key];
  final defaultVal = binding?.defaultNode;
  if (defaultVal == null) return null;
  final value = ctx.view.textOf(defaultVal);
  final unwrapped = unwrapTSNode(defaultVal);
  if (inferredType != null &&
      inferredType.isNotEmpty &&
      !inferredType.contains('null')) {
    final valueType = inferValueType(unwrapped);
    if (valueType != null && !inferredType.contains(valueType)) {
      ctx.fail(
        'Default value of prop "$key" does not match declared type.',
        unwrapped,
      );
    }
  }
  final needSkipFactory = inferredType == null &&
      (isFunctionType(unwrapped) || unwrapped.type == 'identifier');
  final needFactoryWrap = !needSkipFactory &&
      !isLiteralNode(unwrapped) &&
      !(inferredType?.contains('Function') ?? false);
  return needFactoryWrap ? '() => ($value)' : value;
}

/// Static withDefaults pair lookup (hasStaticWithDefaults path).
String? _staticDefaultForKey(SetupContext ctx, String key) {
  final defaults = ctx.propsRuntimeDefaults;
  if (defaults == null || defaults.type != 'object') return null;
  for (final pair in defaults.children) {
    if (pair.type != 'pair') continue;
    final k = childOfType(pair, 'property_identifier') ??
        childOfType(pair, 'string');
    if (k == null) continue;
    var name = ctx.view.textOf(k);
    if (k.type == 'string' && name.length >= 2) {
      name = name.substring(1, name.length - 1);
    }
    if (name == key) {
      final value = pair.children.isEmpty ? null : pair.children.last;
      return value == null ? null : ctx.view.textOf(value);
    }
  }
  return null;
}

String _genPropEntry(SetupContext ctx, _RuntimeProp p, bool staticDefaults) {
  String? defaultString = _destructuredDefault(ctx, p.key, p.types);
  if (defaultString != null) {
    defaultString = 'default: $defaultString';
  } else if (staticDefaults) {
    final d = _staticDefaultForKey(ctx, p.key);
    if (d != null) defaultString = 'default: $d';
  }
  final parts = <String?>[
    'type: ${toRuntimeTypeString(p.types)}',
    'required: ${p.required}',
    p.skipCheck ? 'skipCheck: true' : null,
    defaultString,
  ];
  return '${escapedPropName(p.key)}: { ${_concatStrings(parts)} }';
}

bool _staticDefaults(SetupContext ctx) {
  final d = ctx.propsRuntimeDefaults;
  if (d == null || d.type != 'object') return false;
  for (final c in d.children) {
    if (c.type == 'spread_element') return false;
    if (c.type == 'pair') {
      final k = childOfType(c, 'property_identifier') ??
          childOfType(c, 'string') ??
          childOfType(c, 'number');
      if (k == null) return false; // computed key
    }
  }
  return true;
}

String? _extractPropsFromType(SetupContext ctx) {
  final props = _propsFromType(ctx);
  if (props.isEmpty) return null;
  final staticDefaults = _staticDefaults(ctx);
  final entries =
      props.map((p) => _genPropEntry(ctx, p, staticDefaults)).toList();
  var decls = '{\n    ${entries.join(',\n    ')}\n  }';
  if (ctx.propsRuntimeDefaults != null && !staticDefaults) {
    final defaults = ctx.view.textOf(ctx.propsRuntimeDefaults!);
    decls = '/*@__PURE__*/${ctx.helper('mergeDefaults')}($decls, $defaults)';
  }
  return decls;
}

String? genRuntimeProps(SetupContext ctx) {
  String? propsDecls;
  if (ctx.propsRuntimeDecl != null) {
    propsDecls = ctx.view.textOf(ctx.propsRuntimeDecl!).trim();
    if (ctx.propsDestructureDecl != null) {
      final defaults = <String>[];
      for (final key in ctx.propsDestructuredBindings.keys) {
        final d = _destructuredDefault(ctx, key, null);
        if (d == null) continue;
        final finalKey = escapedPropName(key);
        final binding = ctx.propsDestructuredBindings[key]!;
        final unwrapped = unwrapTSNode(binding.defaultNode!);
        final skip = isFunctionType(unwrapped) || unwrapped.type == 'identifier';
        defaults.add(
          '$finalKey: $d${skip ? ', __skip_$finalKey: true' : ''}',
        );
      }
      if (defaults.isNotEmpty) {
        propsDecls = '/*@__PURE__*/${ctx.helper('mergeDefaults')}'
            '($propsDecls, {\n  ${defaults.join(',\n  ')}\n})';
      }
    }
  } else if (ctx.propsTypeDecl != null) {
    propsDecls = _extractPropsFromType(ctx);
  }
  final modelsDecls = genModelProps(ctx);
  if (propsDecls != null && modelsDecls != null) {
    return '/*@__PURE__*/${ctx.helper('mergeModels')}($propsDecls, $modelsDecls)';
  }
  return modelsDecls ?? propsDecls;
}

Set<String> extractRuntimeEmits(SetupContext ctx) {
  final emits = <String>{};
  final node = ctx.emitsTypeDecl!;
  if (node.type == 'function_type') {
    _extractEventNames(node, ctx.view, emits);
    return emits;
  }
  final elements = resolveTypeElements(node, ctx.view, ctx.typeScope);
  for (final key in elements.props.keys) {
    emits.add(key);
  }
  if (elements.calls.isNotEmpty) {
    if (elements.props.isNotEmpty) {
      ctx.fail(
        'defineEmits() type cannot mixed call signature and property syntax.',
        node,
      );
    }
    for (final call in elements.calls) {
      _extractEventNames(call, ctx.view, emits);
    }
  }
  return emits;
}

void _extractEventNames(AstNode fn, SrcView view, Set<String> emits) {
  final params = childOfType(fn, 'formal_parameters');
  if (params == null || params.children.isEmpty) return;
  final first = params.children.first;
  final ann = childOfType(first, 'type_annotation');
  if (ann == null) return;
  _collectStringLiterals(ann, view, emits);
}

void _collectStringLiterals(AstNode node, SrcView view, Set<String> out) {
  if (node.type == 'literal_type') {
    final s = childOfType(node, 'string');
    if (s != null) {
      final frag = childOfType(s, 'string_fragment');
      if (frag != null) out.add(view.textOf(frag));
    }
    return;
  }
  for (final c in node.children) {
    _collectStringLiterals(c, view, out);
  }
}

String? genRuntimeEmits(SetupContext ctx) {
  var emitsDecl = '';
  if (ctx.emitsRuntimeDecl != null) {
    emitsDecl = ctx.view.textOf(ctx.emitsRuntimeDecl!).trim();
  } else if (ctx.emitsTypeDecl != null) {
    final events = extractRuntimeEmits(ctx);
    emitsDecl =
        events.isEmpty ? '' : '[${events.map(jsonString).join(', ')}]';
  }
  if (ctx.hasDefineModelCall) {
    final modelEvents =
        '[${ctx.modelDecls.keys.map((n) => jsonString('update:$n')).join(', ')}]';
    emitsDecl = emitsDecl.isNotEmpty
        ? '/*@__PURE__*/${ctx.helper('mergeModels')}($emitsDecl, $modelEvents)'
        : modelEvents;
  }
  return emitsDecl.isEmpty ? null : emitsDecl;
}

String? genModelProps(SetupContext ctx) {
  if (!ctx.hasDefineModelCall) return null;
  var decls = '';
  for (final entry in ctx.modelDecls.entries) {
    final decl = _genModelEntry(ctx, entry.value);
    decls += '\n    ${jsonString(entry.key)}: $decl,';
    final modifiers =
        entry.key == 'modelValue' ? 'modelModifiers' : '${entry.key}Modifiers';
    decls += '\n    ${jsonString(modifiers)}: {},';
  }
  return '{$decls\n  }';
}

String _genModelEntry(SetupContext ctx, ModelDecl model) {
  var codegen = '';
  if (model.typeNode != null) {
    var types = inferRuntimeType(model.typeNode!, ctx.view, ctx.typeScope);
    var skipCheck = false;
    if (types.contains(unknownType)) {
      if (types.contains('Boolean') || types.contains('Function')) {
        types = types.where((t) => t != unknownType).toList();
        skipCheck = true;
      } else {
        types = const ['null'];
      }
    }
    codegen = 'type: ${toRuntimeTypeString(types)}';
    if (skipCheck) codegen += ', skipCheck: true';
  }
  final options = model.optionsText;
  if (codegen.isNotEmpty && options != null) {
    return ctx.ts
        ? '{ $codegen, ...$options }'
        : 'Object.assign({ $codegen }, $options)';
  }
  if (codegen.isNotEmpty) return '{ $codegen }';
  return options ?? '{}';
}
