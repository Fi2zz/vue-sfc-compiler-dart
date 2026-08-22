// Port of compiler-core transformElement.ts buildProps + helpers.
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import 'hoist_static.dart';
import 'transform_element.dart' show resolveSetupReference;

final class PropsBuildResult {
  Object? props;
  List<DirectiveNode> directives;
  int patchFlag;
  List<String> dynamicPropNames;
  bool shouldUseBlock;
  PropsBuildResult(this.props, this.directives, this.patchFlag,
      this.dynamicPropNames, this.shouldUseBlock);
}

bool isComponentTag(String tag) => tag == 'component' || tag == 'Component';

class _BuildPropsState {
  List<JSProperty> properties = [];
  List<Object?> mergeArgs = [];
  List<DirectiveNode> runtimeDirectives = [];
  int patchFlag = 0;
  bool hasRef = false;
  bool hasClassBinding = false;
  bool hasStyleBinding = false;
  bool hasHydrationEventBinding = false;
  bool hasDynamicKeys = false;
  bool hasVnodeHook = false;
  bool shouldUseBlock = false;
  final List<String> dynamicPropNames = [];
}

PropsBuildResult buildProps(ElementNode node, TransformContext context,
    {List<TmplNode>? props,
    required bool isComponent,
    required bool isDynamicComponent,
    bool ssr = false}) {
  final propList = props ?? node.props;
  final elementLoc = node.loc;
  final st = _BuildPropsState();
  final hasChildren = node.children.isNotEmpty;

  void pushMergeArg([Object? arg]) {
    if (st.properties.isNotEmpty) {
      st.mergeArgs
          .add(createObjectExp(dedupeProperties(st.properties), elementLoc));
      st.properties = [];
    }
    if (arg != null) st.mergeArgs.add(arg);
  }

  void pushRefVForMarker() {
    if (context.scopes.vFor > 0) {
      st.properties.add(createObjectProp(
          createSimpleExp('ref_for', true), createSimpleExp('true')));
    }
  }

  for (var i = 0; i < propList.length; i++) {
    final prop = propList[i];
    if (prop is AttributeNode) {
      _buildStaticProp(node, context, prop, st, pushRefVForMarker);
    } else if (prop is DirectiveNode) {
      _buildDirectiveProp(node, context, prop, st, isComponent,
          isDynamicComponent, ssr, hasChildren, pushMergeArg, pushRefVForMarker);
    }
  }
  final propsExpression =
      _assemblePropsExpression(st, elementLoc, context);
  _applyPatchFlags(st, isComponent);
  if (!context.inSSR && propsExpression != null) {
    return PropsBuildResult(
        _normalizePropsExpression(propsExpression, st, context),
        st.runtimeDirectives,
        st.patchFlag,
        st.dynamicPropNames,
        st.shouldUseBlock);
  }
  return PropsBuildResult(propsExpression, st.runtimeDirectives, st.patchFlag,
      st.dynamicPropNames, st.shouldUseBlock);
}

void _buildStaticProp(ElementNode node, TransformContext context,
    AttributeNode prop, _BuildPropsState st, void Function() pushRefVForMarker) {
  final name = prop.name;
  final value = prop.value;
  var isStatic = true;
  if (name == 'ref') {
    st.hasRef = true;
    pushRefVForMarker();
    if (value != null && context.inline) {
      final binding = context.bindingMetadata[value.content];
      if (binding == 'setup-let' ||
          binding == 'setup-ref' ||
          binding == 'setup-maybe-ref') {
        isStatic = false;
        st.properties.add(createObjectProp(createSimpleExp('ref_key', true),
            createSimpleExp(value.content, true, value.loc)));
      }
    }
  }
  if (name == 'is' &&
      (isComponentTag(node.tag) ||
          (value != null && value.content.startsWith('vue:')))) {
    return;
  }
  st.properties.add(createObjectProp(
      createSimpleExp(name, true, prop.nameLoc),
      createSimpleExp(value?.content ?? '', isStatic,
          value != null ? value.loc : prop.loc)));
}

void _buildDirectiveProp(
    ElementNode node,
    TransformContext context,
    DirectiveNode prop,
    _BuildPropsState st,
    bool isComponent,
    bool isDynamicComponent,
    bool ssr,
    bool hasChildren,
    void Function([Object? arg]) pushMergeArg,
    void Function() pushRefVForMarker) {
  final name = prop.name;
  final arg = prop.arg;
  final isVBind = name == 'bind';
  final isVOn = name == 'on';
  if (_skipDirective(node, context, prop, isVBind, isVOn, ssr, isComponent)) {
    return;
  }
  _maybeForceBlock(prop, isVBind, isVOn, hasChildren, st);
  if (isVBind && isStaticArgOf(arg, 'ref')) pushRefVForMarker();
  if (arg == null && (isVBind || isVOn)) {
    _buildArglessDirective(node, context, prop, st, isVBind, isComponent,
        pushMergeArg, pushRefVForMarker);
    return;
  }
  if (isVBind && prop.modifiers.any((m) => m.content == 'prop')) {
    st.patchFlag |= 32;
  }
  _runDirectiveTransform(node, context, prop, st, isVOn, pushMergeArg,
      hasChildren, isComponent, isDynamicComponent);
}

bool _skipDirective(ElementNode node, TransformContext context,
    DirectiveNode prop, bool isVBind, bool isVOn, bool ssr, bool isComponent) {
  final name = prop.name;
  if (name == 'slot') {
    if (!isComponent) {
      context.onError(TmplCompileError(
          40, 'v-slot can only be used on components or <template> tags.',
          prop.loc));
    }
    return true;
  }
  if (name == 'once' || name == 'memo') return true;
  if (name == 'is' ||
      (isVBind &&
          isStaticArgOf(prop.arg, 'is') &&
          isComponentTag(node.tag))) {
    return true;
  }
  if (isVOn && ssr) return true;
  return false;
}

void _maybeForceBlock(DirectiveNode prop, bool isVBind, bool isVOn,
    bool hasChildren, _BuildPropsState st) {
  if ((isVBind && isStaticArgOf(prop.arg, 'key')) ||
      (isVOn && hasChildren && isStaticArgOf(prop.arg, 'vue:before-update'))) {
    st.shouldUseBlock = true;
  }
}

void _buildArglessDirective(
    ElementNode node,
    TransformContext context,
    DirectiveNode prop,
    _BuildPropsState st,
    bool isVBind,
    bool isComponent,
    void Function([Object? arg]) pushMergeArg,
    void Function() pushRefVForMarker) {
  st.hasDynamicKeys = true;
  final exp = prop.exp;
  if (exp == null) {
    context.onError(TmplCompileError(
        isVBind ? 34 : 35,
        isVBind
            ? 'v-bind is missing expression.'
            : 'v-on is missing expression.',
        prop.loc));
    return;
  }
  if (isVBind) {
    pushMergeArg();
    pushRefVForMarker();
    pushMergeArg();
    st.mergeArgs.add(exp);
  } else {
    context.helper(hToHandlers);
    pushMergeArg(
        createCallExp(hToHandlers, isComponent ? [exp] : [exp, 'true']));
  }
}

void _runDirectiveTransform(
    ElementNode node,
    TransformContext context,
    DirectiveNode prop,
    _BuildPropsState st,
    bool isVOn,
    void Function([Object? arg]) pushMergeArg,
    bool hasChildren,
    bool isComponent,
    bool isDynamicComponent) {
  final directiveTransform = context.directiveTransforms[prop.name];
  if (directiveTransform != null) {
    final result = directiveTransform(prop, node, context);
    for (final p in result.props) {
      _analyzePatchFlag(p, st, isComponent, isDynamicComponent, context);
    }
    if (isVOn && prop.arg != null && !isStaticExp(prop.arg)) {
      pushMergeArg(createObjectExp(result.props, node.loc));
    } else {
      st.properties.addAll(result.props);
    }
    if (result.needRuntime != null) {
      st.runtimeDirectives.add(prop);
      if (result.needRuntime is String) {
        directiveImportMap[prop] = result.needRuntime as String;
      }
    }
  } else if (!isBuiltInDirective(prop.name)) {
    st.runtimeDirectives.add(prop);
    if (hasChildren) st.shouldUseBlock = true;
  }
}

void _analyzePatchFlag(JSProperty property, _BuildPropsState st,
    bool isComponent, bool isDynamicComponent, TransformContext context) {
  final key = property.key;
  var value = property.value;
  if (key is! SimpleExpression || !key.static_) {
    st.hasDynamicKeys = true;
    return;
  }
  final name = key.content;
  final isEventHandler = isOn(name);
  if (isEventHandler &&
      (!isComponent || isDynamicComponent) &&
      name.toLowerCase() != 'onclick' &&
      name != 'onUpdate:modelValue' &&
      !isReservedProp(name)) {
    st.hasHydrationEventBinding = true;
  }
  if (isEventHandler && isReservedProp(name)) st.hasVnodeHook = true;
  if (isEventHandler && value is JSCallExpression) {
    value = value.arguments.isNotEmpty ? value.arguments[0] : value;
  }
  final constant = value is JSCacheExpression ||
      ((value is SimpleExpression || value is CompoundExpression) &&
          getConstantType(value as TmplNode, context) > 0);
  if (constant) return;
  if (name == 'ref') {
    st.hasRef = true;
  } else if (name == 'class') {
    st.hasClassBinding = true;
  } else if (name == 'style') {
    st.hasStyleBinding = true;
  } else if (name != 'key' && !st.dynamicPropNames.contains(name)) {
    st.dynamicPropNames.add(name);
  }
  if (isComponent &&
      (name == 'class' || name == 'style') &&
      !st.dynamicPropNames.contains(name)) {
    st.dynamicPropNames.add(name);
  }
}

Object? _assemblePropsExpression(
    _BuildPropsState st, TmplLoc elementLoc, TransformContext context) {
  if (st.mergeArgs.isNotEmpty) {
    _flushMergeProperties(st, elementLoc);
    if (st.mergeArgs.length > 1) {
      context.helper(hMergeProps);
      return createCallExp(hMergeProps, st.mergeArgs, elementLoc);
    }
    return st.mergeArgs[0];
  }
  if (st.properties.isNotEmpty) {
    return createObjectExp(dedupeProperties(st.properties), elementLoc);
  }
  return null;
}

void _flushMergeProperties(_BuildPropsState st, TmplLoc elementLoc) {
  if (st.properties.isNotEmpty) {
    st.mergeArgs
        .add(createObjectExp(dedupeProperties(st.properties), elementLoc));
    st.properties = [];
  }
}

void _applyPatchFlags(_BuildPropsState st, bool isComponent) {
  if (st.hasDynamicKeys) {
    st.patchFlag |= 16;
  } else {
    if (st.hasClassBinding && !isComponent) st.patchFlag |= 2;
    if (st.hasStyleBinding) st.patchFlag |= 4;
    if (st.dynamicPropNames.isNotEmpty) st.patchFlag |= 8;
    if (st.hasHydrationEventBinding) st.patchFlag |= 32;
  }
  if (!st.shouldUseBlock &&
      (st.patchFlag == 0 || st.patchFlag == 32) &&
      (st.hasRef || st.hasVnodeHook || st.runtimeDirectives.isNotEmpty)) {
    st.patchFlag |= 512;
  }
}

Object? _normalizePropsExpression(
    Object propsExpression, _BuildPropsState st, TransformContext context) {
  switch (propsExpression) {
    case JSObjectExpression objExpr:
      return _normalizeObjectProps(objExpr, st, context);
    case JSCallExpression _:
      return propsExpression;
    default:
      context.helper(hNormalizeProps);
      context.helper(hGuardReactiveProps);
      return createCallExp(hNormalizeProps, [
        createCallExp(hGuardReactiveProps, [propsExpression])
      ]);
  }
}

Object? _normalizeObjectProps(
    JSObjectExpression objExpr, _BuildPropsState st, TransformContext context) {
  var classKeyIndex = -1;
  var styleKeyIndex = -1;
  var hasDynamicKey = false;
  for (var i = 0; i < objExpr.properties.length; i++) {
    final key = objExpr.properties[i].key;
    if (key is SimpleExpression && key.static_) {
      if (key.content == 'class') classKeyIndex = i;
      if (key.content == 'style') styleKeyIndex = i;
    } else if (key is! SimpleExpression || !key.isHandlerKey) {
      hasDynamicKey = true;
    }
  }
  if (hasDynamicKey) {
    context.helper(hNormalizeProps);
    return createCallExp(hNormalizeProps, [objExpr]);
  }
  _normalizeClassProp(objExpr, classKeyIndex, context);
  _normalizeStyleProp(objExpr, styleKeyIndex, st, context);
  return objExpr;
}

void _normalizeClassProp(
    JSObjectExpression objExpr, int classKeyIndex, TransformContext context) {
  final classProp =
      classKeyIndex >= 0 ? objExpr.properties[classKeyIndex] : null;
  if (classProp != null && !isStaticExp(classProp.value)) {
    context.helper(hNormalizeClass);
    classProp.value = createCallExp(hNormalizeClass, [classProp.value]);
  }
}

void _normalizeStyleProp(JSObjectExpression objExpr, int styleKeyIndex,
    _BuildPropsState st, TransformContext context) {
  final styleProp =
      styleKeyIndex >= 0 ? objExpr.properties[styleKeyIndex] : null;
  if (styleProp == null) return;
  final value = styleProp.value;
  final dynamicArrayLiteral = value is SimpleExpression &&
      value.content.trim().isNotEmpty &&
      value.content.trim()[0] == '[';
  if (st.hasStyleBinding ||
      dynamicArrayLiteral ||
      value is JSArrayExpression) {
    context.helper(hNormalizeStyle);
    styleProp.value = createCallExp(hNormalizeStyle, [value]);
  }
}

List<JSProperty> dedupeProperties(List<JSProperty> properties) {
  final knownProps = <String, JSProperty>{};
  final deduped = <JSProperty>[];
  for (final prop in properties) {
    final key = prop.key;
    if (key is! SimpleExpression || !key.static_) {
      deduped.add(prop);
      continue;
    }
    final name = key.content;
    final existing = knownProps[name];
    if (existing != null) {
      if (name == 'style' || name == 'class' || isOn(name)) {
        _mergeAsArray(existing, prop);
      }
    } else {
      knownProps[name] = prop;
      deduped.add(prop);
    }
  }
  return deduped;
}

void _mergeAsArray(JSProperty existing, JSProperty incoming) {
  final value = existing.value;
  if (value is JSArrayExpression) {
    value.elements.add(incoming.value);
  } else {
    existing.value = createArrayExp([value, incoming.value], existing.loc);
  }
}

final directiveImportMap = <DirectiveNode, String>{};

JSArrayExpression buildDirectiveArgs(
    DirectiveNode dir, TransformContext context) {
  final dirArgs = <Object?>[];
  final runtime = directiveImportMap[dir];
  if (runtime != null) {
    dirArgs.add(context.helperString(runtime));
  } else {
    dirArgs.add(_resolveDirectiveName(dir, context));
  }
  final loc = dir.loc;
  if (dir.exp != null) dirArgs.add(dir.exp);
  if (dir.arg != null) {
    if (dir.exp == null) dirArgs.add('void 0');
    dirArgs.add(dir.arg);
  }
  if (dir.modifiers.isNotEmpty) {
    if (dir.arg == null) {
      if (dir.exp == null) dirArgs.add('void 0');
      dirArgs.add('void 0');
    }
    final trueExpression = createSimpleExp('true', false, loc);
    dirArgs.add(createObjectExp(
        dir.modifiers
            .map((modifier) => createObjectProp(modifier, trueExpression))
            .toList(),
        loc));
  }
  return createArrayExp(dirArgs, dir.loc);
}

Object _resolveDirectiveName(DirectiveNode dir, TransformContext context) {
  final fromSetup = resolveSetupReference('v-${dir.name}', context);
  if (fromSetup != null) return fromSetup;
  context.helper(hResolveDirective);
  context.directives.add(dir.name);
  return toValidAssetId(dir.name, 'directive');
}

String stringifyDynamicPropNames(List<String> props) {
  final buf = StringBuffer('[');
  for (var i = 0; i < props.length; i++) {
    buf.write(_jsStringify(props[i]));
    if (i < props.length - 1) buf.write(', ');
  }
  buf.write(']');
  return buf.toString();
}

String _jsStringify(String s) {
  final escaped = s
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
  return '"$escaped"';
}
