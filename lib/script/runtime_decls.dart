// Port of genRuntimeProps / genRuntimeEmits / genModelProps output formats.
import 'package:vue_sfc_parser/ts_parser.dart';

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
  final view = SrcView(ctx.setupSource);
  final elements = resolveTypeElements(ctx.propsTypeDecl!, view, ctx.typeScope);
  final out = <_RuntimeProp>[];
  for (final key in elements.props.keys) {
    final e = elements.props[key]!;
    var types = e.method
        ? const ['Function']
        : e.typeNode == null
        ? const [unknownType]
        : inferRuntimeType(e.typeNode!, view, ctx.typeScope);
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

String? _defaultForKey(SetupContext ctx, String key) {
  final destructured = ctx.destructuredDefaults[key];
  if (destructured != null) return destructured;
  final defaults = ctx.propsRuntimeDefaults;
  if (defaults == null || defaults.type != 'object') return null;
  final view = SrcView(ctx.setupSource);
  for (final pair in childrenOfType(defaults, 'pair')) {
    final k = childOfType(pair, 'property_identifier') ?? childOfType(pair, 'string');
    if (k == null) continue;
    var name = view.textOf(k);
    if (k.type == 'string' && name.length >= 2) {
      name = name.substring(1, name.length - 1);
    }
    if (name == key) {
      final value = pair.children.isEmpty ? null : pair.children.last;
      return value == null ? null : view.textOf(value);
    }
  }
  return null;
}

String _genPropEntry(SetupContext ctx, _RuntimeProp p) {
  final defaultValue = _defaultForKey(ctx, p.key);
  final parts = <String?>[
    'type: ${toRuntimeTypeString(p.types)}',
    'required: ${p.required}',
    p.skipCheck ? 'skipCheck: true' : null,
    defaultValue == null ? null : 'default: $defaultValue',
  ];
  return '${escapedPropName(p.key)}: { ${_concatStrings(parts)} }';
}

String? _extractPropsFromType(SetupContext ctx) {
  final props = _propsFromType(ctx);
  if (props.isEmpty) return null;
  final entries = props.map((p) => _genPropEntry(ctx, p)).toList();
  var decls = '{\n    ${entries.join(',\n    ')}\n  }';
  if (ctx.propsRuntimeDefaults != null && !_staticDefaults(ctx)) {
    final view = SrcView(ctx.setupSource);
    final defaults = view.textOf(ctx.propsRuntimeDefaults!);
    decls = '/*@__PURE__*/${ctx.helper('mergeDefaults')}($decls, $defaults)';
  }
  return decls;
}

bool _staticDefaults(SetupContext ctx) {
  final d = ctx.propsRuntimeDefaults;
  return d != null && d.type == 'object';
}

String? genRuntimeProps(SetupContext ctx) {
  String? propsDecls;
  final view = SrcView(ctx.setupSource);
  if (ctx.propsRuntimeDecl != null) {
    propsDecls = view.textOf(ctx.propsRuntimeDecl!).trim();
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
  final view = SrcView(ctx.setupSource);
  final emits = <String>{};
  final node = ctx.emitsTypeDecl!;
  if (node.type == 'function_type') {
    _extractEventNames(node, view, emits);
    return emits;
  }
  final elements = resolveTypeElements(node, view, ctx.typeScope);
  for (final key in elements.props.keys) {
    emits.add(key);
  }
  if (elements.calls.isNotEmpty) {
    if (elements.props.isNotEmpty) {
      throwEmitsMixed(ctx, node);
    }
    for (final call in elements.calls) {
      _extractEventNames(call, view, emits);
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
  final view = SrcView(ctx.setupSource);
  if (ctx.emitsRuntimeDecl != null) {
    emitsDecl = view.textOf(ctx.emitsRuntimeDecl!).trim();
  } else if (ctx.emitsTypeDecl != null) {
    final events = extractRuntimeEmits(ctx);
    emitsDecl = events.isEmpty
        ? ''
        : '[${events.map(jsonString).join(', ')}]';
  }
  if (ctx.modelDecls.isNotEmpty) {
    final modelEvents =
        '[${ctx.modelDecls.keys.map((n) => jsonString('update:$n')).join(', ')}]';
    emitsDecl = emitsDecl.isNotEmpty
        ? '/*@__PURE__*/${ctx.helper('mergeModels')}($emitsDecl, $modelEvents)'
        : modelEvents;
  }
  return emitsDecl.isEmpty ? null : emitsDecl;
}

String? genModelProps(SetupContext ctx) {
  if (ctx.modelDecls.isEmpty) return null;
  final view = SrcView(ctx.setupSource);
  var decls = '';
  for (final entry in ctx.modelDecls.entries) {
    final decl = _genModelEntry(ctx, entry.value, view);
    decls += '\n    ${jsonString(entry.key)}: $decl,';
    final modifiers =
        entry.key == 'modelValue' ? 'modelModifiers' : '${entry.key}Modifiers';
    decls += '\n    ${jsonString(modifiers)}: {},';
  }
  return '{$decls\n  }';
}

String _genModelEntry(SetupContext ctx, ModelDecl model, SrcView view) {
  var codegen = '';
  if (model.typeNode != null) {
    var types = inferRuntimeType(model.typeNode!, view, ctx.typeScope);
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
    return '{ $codegen, ...$options }';
  }
  if (codegen.isNotEmpty) return '{ $codegen }';
  return options ?? '{}';
}
