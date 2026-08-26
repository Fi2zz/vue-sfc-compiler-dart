// Port of official processDefine* macro handlers. Applies edits to the
// MiniMagic splice buffer and records state on SetupContext.
import '../ts_parser.dart';

import 'mini_magic.dart';
import 'runtime_decls.dart';
import 'setup_context.dart';
import 'src_view.dart';

const macros = [
  'defineProps',
  'defineEmits',
  'defineExpose',
  'withDefaults',
  'defineOptions',
  'defineSlots',
  'defineModel',
];

String? _callName(AstNode? node, SrcView view) {
  if (node == null || node.type != 'call_expression') return null;
  final id = childOfType(node, 'identifier');
  return id == null ? null : view.textOf(id);
}

bool isCallOf(AstNode? node, String name, SrcView view) =>
    _callName(node, view) == name;

AstNode? _typeArg(AstNode call) {
  final t = childOfType(call, 'type_arguments');
  if (t == null) return null;
  for (final c in t.children) {
    if (c.type == 'comment') continue;
    return c;
  }
  return null;
}

/// Official hasVueIgnore at the type-arguments level: a comment before the
/// type node marks its first member ignored (babel leadingComments quirk).
bool _typeLeadingIgnored(SrcView view, AstNode call, AstNode typeArg) {
  final t = childOfType(call, 'type_arguments');
  if (t == null) return false;
  var found = false;
  for (final c in t.children) {
    if (identical(c, typeArg)) break;
    if (c.type == 'comment' && view.textOf(c).contains('@vue-ignore')) {
      found = true;
    }
  }
  return found;
}

/// Port of getObjectOrArrayExpressionKeys: keys of a runtime props/emits
/// declaration (array of string literals or object literal keys).
List<String> _declKeys(AstNode node, SrcView view) {
  final inner = node.type == 'parenthesized_expression'
      ? node.children.first
      : node;
  if (inner.type == 'array') {
    return [
      for (final e in inner.children)
        if (e.type == 'string') _stringValue(view, e),
    ];
  }
  if (inner.type == 'object') {
    return [
      for (final p in inner.children)
        if (p.type == 'pair') _pairKey(p, view),
    ];
  }
  return const [];
}

String _pairKey(AstNode pair, SrcView view) {
  final key = pair.children.first;
  if (key.type == 'string') return _stringValue(view, key);
  return view.textOf(key);
}

List<AstNode> _args(AstNode call) {
  final a = childOfType(call, 'arguments');
  return a?.children ?? const [];
}

/// defineProps / withDefaults. [declId] is the declarator id node if assigned.
bool processDefineProps(
  SetupContext ctx,
  AstNode node, {
  AstNode? declId,
  bool withDefaults = false,
}) {
  if (!isCallOf(node, 'defineProps', ctx.view)) {
    return _processWithDefaults(ctx, node, declId: declId);
  }
  if (ctx.hasDefinePropsCall) {
    ctx.fail('duplicate defineProps() call', node);
  }
  ctx.hasDefinePropsCall = true;
  final args = _args(node);
  ctx.propsRuntimeDecl = args.isEmpty ? null : args.first;
  if (ctx.propsRuntimeDecl != null) {
    // 官方：runtime 声明的每个 props 键登记进 bindingMetadata（putIfAbsent）
    ctx.propsKeys.addAll(_declKeys(ctx.propsRuntimeDecl!, ctx.view));
  }
  final typeArg = _typeArg(node);
  if (typeArg != null) {
    if (ctx.propsRuntimeDecl != null) {
      ctx.fail(
        'defineProps() cannot accept both type and non-type arguments '
        'at the same time. Use one or the other.',
        node,
      );
    }
    ctx.propsTypeDecl = typeArg;
    ctx.propsTypeLeadingIgnored = _typeLeadingIgnored(ctx.view, node, typeArg);
  }
  if (!withDefaults && declId != null && declId.type == 'object_pattern') {
    _processPropsDestructure(ctx, declId);
  }
  ctx.propsCall = node;
  ctx.propsAssigned = declId != null;
  return true;
}

bool _processWithDefaults(SetupContext ctx, AstNode node, {AstNode? declId}) {
  if (!isCallOf(node, 'withDefaults', ctx.view)) return false;
  final args = _args(node);
  final first = args.isEmpty ? null : args.first;
  if (first == null ||
      !processDefineProps(ctx, first, declId: declId, withDefaults: true)) {
    ctx.fail(
      "withDefaults' first argument must be a defineProps call.",
      first ?? node,
    );
  }
  if (ctx.propsRuntimeDecl != null) {
    ctx.fail(
      'withDefaults can only be used with type-based defineProps declaration.',
      node,
    );
  }
  if (args.length < 2) {
    ctx.fail('The 2nd argument of withDefaults is required.', node);
  }
  ctx.propsRuntimeDefaults = args[1];
  ctx.propsCall = node;
  return true;
}

void _processPropsDestructure(SetupContext ctx, AstNode pattern) {
  ctx.propsDestructureDecl = pattern;
  for (final p in pattern.children) {
    if (p.type == 'shorthand_property_identifier_pattern') {
      final key = ctx.view.textOf(p);
      ctx.propsDestructuredBindings[key] = DestructureBinding(key, null);
    } else if (p.type == 'object_assignment_pattern') {
      // { x = 1 }
      final id = childOfType(p, 'shorthand_property_identifier_pattern');
      if (id == null) continue;
      final key = ctx.view.textOf(id);
      ctx.propsDestructuredBindings[key] = DestructureBinding(
        key,
        p.children.last,
      );
    } else if (p.type == 'pair_pattern') {
      _pairDestructure(ctx, p);
    } else if (p.type == 'rest_pattern') {
      final id = childOfType(p, 'identifier');
      if (id != null) ctx.propsDestructureRestId = ctx.view.textOf(id);
    }
  }
}

void _pairDestructure(SetupContext ctx, AstNode pair) {
  final keyNode = childOfType(pair, 'property_identifier');
  if (keyNode == null) return;
  final key = ctx.view.textOf(keyNode);
  final value = pair.children.last;
  if (value.type == 'identifier') {
    ctx.propsDestructuredBindings[key] = DestructureBinding(
      ctx.view.textOf(value),
      null,
    );
  } else if (value.type == 'assignment_pattern') {
    final left = value.children.first;
    if (left.type == 'identifier') {
      ctx.propsDestructuredBindings[key] = DestructureBinding(
        ctx.view.textOf(left),
        value.children.last,
      );
    }
  }
}

/// defineEmits. Returns true when the call was consumed.
bool processDefineEmits(SetupContext ctx, AstNode node, {AstNode? declId}) {
  if (!isCallOf(node, 'defineEmits', ctx.view)) return false;
  if (ctx.hasDefineEmitCall) {
    ctx.fail('duplicate defineEmits() call', node);
  }
  ctx.hasDefineEmitCall = true;
  final args = _args(node);
  ctx.emitsRuntimeDecl = args.isEmpty ? null : args.first;
  final typeArg = _typeArg(node);
  if (typeArg != null) {
    if (ctx.emitsRuntimeDecl != null) {
      ctx.fail(
        'defineEmits() cannot accept both type and non-type arguments '
        'at the same time. Use one or the other.',
        node,
      );
    }
    ctx.emitsTypeDecl = typeArg;
  }
  ctx.emitAssigned = declId != null;
  return true;
}

/// defineExpose expression statement. Only call-site rewrite happens here.
bool processDefineExpose(SetupContext ctx, AstNode node, MiniMagic s) {
  if (!isCallOf(node, 'defineExpose', ctx.view)) return false;
  if (ctx.hasDefineExposeCall) {
    ctx.fail('duplicate defineExpose() call', node);
  }
  ctx.hasDefineExposeCall = true;
  final callee = childOfType(node, 'identifier')!;
  s.overwrite(ctx.abs(callee.startByte), ctx.abs(callee.endByte), '__expose');
  return true;
}

/// defineOptions. Validates forbidden option keys.
bool processDefineOptions(SetupContext ctx, AstNode node) {
  if (!isCallOf(node, 'defineOptions', ctx.view)) return false;
  if (ctx.hasDefineOptionsCall) {
    ctx.fail('duplicate defineOptions() call', node);
  }
  if (childOfType(node, 'type_arguments') != null) {
    ctx.fail('defineOptions() cannot accept type arguments', node);
  }
  final args = _args(node);
  if (args.isEmpty) return true;
  ctx.hasDefineOptionsCall = true;
  ctx.optionsRuntimeDecl = args.first;
  _checkForbiddenOptions(ctx, args.first);
  return true;
}

void _checkForbiddenOptions(SetupContext ctx, AstNode options) {
  if (options.type != 'object') return;
  const forbidden = {
    'props': 'defineProps',
    'emits': 'defineEmits',
    'expose': 'defineExpose',
    'slots': 'defineSlots',
  };
  for (final pair in objectProperties(options)) {
    if (pair.type != 'pair') continue;
    final key = childOfType(pair, 'property_identifier');
    if (key == null) continue;
    final target = forbidden[ctx.view.textOf(key)];
    if (target != null) {
      final name = ctx.view.textOf(key);
      ctx.fail(
        'defineOptions() cannot be used to declare $name. '
        'Use $target() instead.',
        pair,
      );
    }
  }
}

/// Object literal "properties" in source order: pairs + methods + spread.
List<AstNode> objectProperties(AstNode object) {
  return object.children
      .where(
        (c) =>
            c.type == 'pair' ||
            c.type == 'method_definition' ||
            c.type == 'spread_element',
      )
      .toList(growable: false);
}

String? _propertyKeyText(SetupContext ctx, AstNode prop) {
  if (prop.type != 'pair' && prop.type != 'method_definition') return null;
  final key =
      childOfType(prop, 'property_identifier') ?? childOfType(prop, 'string');
  if (key == null) return null;
  var name = ctx.view.textOf(key);
  if (key.type == 'string' && name.length >= 2) {
    name = name.substring(1, name.length - 1);
  }
  return name;
}

/// Whether an object literal has spread or computed-key properties.
bool objectHasSpreadOrComputed(SetupContext ctx, AstNode object) {
  for (final c in object.children) {
    if (c.type == 'spread_element') return true;
    if (c.type == 'pair' && _propertyKeyText(ctx, c) == null) return true;
  }
  return false;
}

/// defineSlots. Rewrites to useSlots() when assigned.
bool processDefineSlots(
  SetupContext ctx,
  AstNode node,
  MiniMagic s, {
  AstNode? declId,
}) {
  if (!isCallOf(node, 'defineSlots', ctx.view)) return false;
  if (ctx.hasDefineSlotsCall) {
    ctx.fail('duplicate defineSlots() call', node);
  }
  ctx.hasDefineSlotsCall = true;
  if (_args(node).isNotEmpty) {
    ctx.fail('defineSlots() cannot accept arguments', node);
  }
  if (declId != null) {
    s.overwrite(
      ctx.abs(node.startByte),
      ctx.abs(node.endByte),
      '${ctx.helper('useSlots')}()',
    );
  }
  return true;
}

/// defineModel -> _useModel rewrite + model declaration recording.
bool processDefineModel(SetupContext ctx, AstNode node, MiniMagic s) {
  if (!isCallOf(node, 'defineModel', ctx.view)) return false;
  ctx.hasDefineModelCall = true;
  final args = _args(node);
  final arg0 = args.isEmpty ? null : args.first;
  // Official also accepts expression-free TemplateLiteral names (#14622).
  final hasName =
      arg0 != null &&
      (arg0.type == 'string' ||
          (arg0.type == 'template_string' &&
              !arg0.children.any((c) => c.type == 'template_substitution')));
  final name = hasName ? _stringValue(ctx.view, arg0) : 'modelValue';
  final options = hasName ? (args.length > 1 ? args[1] : null) : arg0;
  if (ctx.modelDecls.containsKey(name)) {
    ctx.fail('duplicate model name ${jsonString(name)}', node);
  }
  final model = _recordModel(ctx, node, name, options);
  ctx.modelDecls[name] = model;
  _rewriteModelCall(ctx, node, s, arg0, options, hasName, model);
  return true;
}

String _stringValue(SrcView view, AstNode stringNode) {
  final frag = childOfType(stringNode, 'string_fragment');
  return frag == null ? view.textOf(stringNode) : view.textOf(frag);
}

ModelDecl _recordModel(
  SetupContext ctx,
  AstNode node,
  String name,
  AstNode? options,
) {
  String? optionsText = options == null ? null : ctx.view.textOf(options);
  if (options != null &&
      options.type == 'object' &&
      !objectHasSpreadOrComputed(ctx, options)) {
    optionsText = _stripGetSet(ctx, options, optionsText!);
  }
  return ModelDecl(name, typeNode: _typeArg(node), optionsText: optionsText);
}

String _stripGetSet(SetupContext ctx, AstNode options, String text) {
  final props = objectProperties(options);
  final ranges = <List<int>>[];
  for (var i = 0; i < props.length; i++) {
    final name = _propertyKeyText(ctx, props[i]);
    if (name != 'get' && name != 'set') continue;
    final start = props[i].startByte;
    final end = i + 1 < props.length
        ? props[i + 1].startByte
        : options.endByte - 1;
    ranges.add([start - options.startByte, end - options.startByte]);
  }
  for (final r in ranges.reversed) {
    text = text.substring(0, r[0]) + text.substring(r[1]);
  }
  return text;
}

void _rewriteModelCall(
  SetupContext ctx,
  AstNode node,
  MiniMagic s,
  AstNode? arg0,
  AstNode? options,
  bool hasName,
  ModelDecl model,
) {
  final callee = childOfType(node, 'identifier')!;
  s.overwrite(
    ctx.abs(callee.startByte),
    ctx.abs(callee.endByte),
    ctx.helper('useModel'),
  );
  var optionsRemoved = options == null;
  if (options != null &&
      options.type == 'object' &&
      !objectHasSpreadOrComputed(ctx, options)) {
    optionsRemoved = _removePropOptions(ctx, s, options, hasName, arg0);
  }
  final injectAt = arg0 != null
      ? ctx.abs(arg0.startByte)
      : ctx.abs(node.endByte) - 1;
  final namePart = hasName
      ? ''
      : '${jsonString(model.name)}${optionsRemoved ? '' : ', '}';
  s.appendLeft(injectAt, '__props, $namePart');
}

bool _removePropOptions(
  SetupContext ctx,
  MiniMagic s,
  AstNode options,
  bool hasName,
  AstNode? arg0,
) {
  final props = objectProperties(options);
  var removed = 0;
  for (var i = props.length - 1; i >= 0; i--) {
    final name = _propertyKeyText(ctx, props[i]);
    if (name == 'get' || name == 'set') continue;
    removed++;
    final start = props[i].startByte;
    final end = i + 1 < props.length
        ? props[i + 1].startByte
        : options.endByte - 1;
    s.remove(ctx.abs(start), ctx.abs(end));
  }
  if (removed == props.length) {
    final from = hasName ? arg0!.endByte : options.startByte;
    s.remove(ctx.abs(from), ctx.abs(options.endByte));
    return true;
  }
  return false;
}
