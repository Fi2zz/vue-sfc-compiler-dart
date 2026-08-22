// Port of compiler-core transformElement.ts: transformElement +
// resolveComponentType + resolveSetupReference.
import 'dart:convert';

import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import 'build_props.dart';
import 'build_slots.dart';
import 'hoist_static.dart';
import 'transform_expression.dart';

export 'build_props.dart';
export 'build_slots.dart';

Object? transformElement(TmplNode node, TransformContext context) {
  return () => _postTransformElement(node, context);
}

void _postTransformElement(TmplNode node, TransformContext context) {
  node = context.currentNode!;
  if (node is! ElementNode ||
      (node.tagType != etElement && node.tagType != etComponent)) {
    return;
  }
  final tag = node.tag;
  final isComponent = node.tagType == etComponent;
  final vnodeTag =
      isComponent ? resolveComponentType(node, context) : '"$tag"';
  final isDynamicComponent = vnodeTag is JSCallExpression &&
      vnodeTag.callee == hResolveDynamicComponent;
  var shouldUseBlock = isDynamicComponent ||
      vnodeTag == hTeleport ||
      vnodeTag == hSuspense ||
      (!isComponent &&
          (tag == 'svg' || tag == 'foreignObject' || tag == 'math'));
  Object? vnodeProps;
  Object? vnodeChildren;
  var patchFlag = 0;
  Object? vnodeDynamicProps;
  List<String>? dynamicPropNames;
  JSArrayExpression? vnodeDirectives;
  if (node.props.isNotEmpty) {
    final r = buildProps(node, context,
        isComponent: isComponent, isDynamicComponent: isDynamicComponent);
    vnodeProps = r.props;
    patchFlag = r.patchFlag;
    dynamicPropNames = r.dynamicPropNames;
    if (r.directives.isNotEmpty) {
      vnodeDirectives = createArrayExp(
          r.directives.map((dir) => buildDirectiveArgs(dir, context)).toList());
    }
    if (r.shouldUseBlock) shouldUseBlock = true;
  }
  if (node.children.isNotEmpty) {
    final cr = _buildChildren(node, vnodeTag, isComponent, context);
    vnodeChildren = cr.$1;
    patchFlag |= cr.$2;
    shouldUseBlock = shouldUseBlock || cr.$3;
  }
  if (dynamicPropNames != null && dynamicPropNames.isNotEmpty) {
    vnodeDynamicProps = stringifyDynamicPropNames(dynamicPropNames);
  }
  node.codegenNode = createVNodeCall(
      context,
      VNodeCallSpec(vnodeTag,
          props: vnodeProps,
          children: vnodeChildren,
          patchFlag: patchFlag == 0 ? null : patchFlag,
          dynamicProps: vnodeDynamicProps,
          directives: vnodeDirectives,
          isBlock: shouldUseBlock,
          isComponent: isComponent,
          loc: node.loc));
}

(Object?, int, bool) _buildChildren(ElementNode node, Object vnodeTag,
    bool isComponent, TransformContext context) {
  var patchFlag = 0;
  var extraBlock = false;
  Object? vnodeChildren;
  if (vnodeTag == hKeepAlive) {
    extraBlock = true;
    patchFlag |= 1024;
    if (node.children.length > 1) {
      context.onError(TmplCompileError(
          46, '<KeepAlive> expects exactly one child component.', node.loc));
    }
  }
  final shouldBuildAsSlots =
      isComponent && vnodeTag != hTeleport && vnodeTag != hKeepAlive;
  if (shouldBuildAsSlots) {
    final r = buildSlots(node, context);
    vnodeChildren = r.slots;
    if (r.hasDynamicSlots) patchFlag |= 1024;
  } else if (node.children.length == 1 && vnodeTag != hTeleport) {
    final child = node.children[0];
    final type = child.type;
    final hasDynamicTextChild =
        type == ntInterpolation || type == ntCompoundExpression;
    if (hasDynamicTextChild && getConstantType(child, context) == 0) {
      patchFlag |= 1;
    }
    if (hasDynamicTextChild || type == ntText) {
      vnodeChildren = child;
    } else {
      vnodeChildren = node.children;
    }
  } else {
    vnodeChildren = node.children;
  }
  return (vnodeChildren, patchFlag, extraBlock);
}

Object resolveComponentType(ElementNode node, TransformContext context,
    [bool ssr = false]) {
  var tag = node.tag;
  final isExplicitDynamic = isComponentTag(tag);
  final isProp = findProp(node, 'is', false, true);
  if (isProp != null) {
    if (isExplicitDynamic) {
      final dynamic = _dynamicComponentExp(context, isProp);
      if (dynamic != null) return dynamic;
    } else if (isProp is AttributeNode &&
        isProp.value != null &&
        isProp.value!.content.startsWith('vue:')) {
      tag = isProp.value!.content.substring(4);
    }
  }
  final builtIn = _coreComponent(tag) ?? builtInComponentOf(context, tag);
  if (builtIn != null) {
    if (!ssr) context.helper(builtIn);
    return builtIn;
  }
  final fromSetup = resolveSetupReference(tag, context);
  if (fromSetup != null) return fromSetup;
  final dotIndex = tag.indexOf('.');
  if (dotIndex > 0) {
    final ns = resolveSetupReference(tag.substring(0, dotIndex), context);
    if (ns != null) return ns + tag.substring(dotIndex);
  }
  if (context.selfName != null &&
      capitalize(camelize(tag)) == context.selfName) {
    context.helper(hResolveComponent);
    context.components.add('${tag}__self');
    return toValidAssetId(tag, 'component');
  }
  context.helper(hResolveComponent);
  context.components.add(tag);
  return toValidAssetId(tag, 'component');
}

Object? _dynamicComponentExp(TransformContext context, Object isProp) {
  Object? exp;
  if (isProp is AttributeNode) {
    final v = isProp.value;
    if (v != null) exp = createSimpleExp(v.content, true);
  } else if (isProp is DirectiveNode) {
    exp = isProp.exp;
    if (exp == null) {
      isProp.exp = createSimpleExp('is', false, isProp.arg?.loc);
      if (context.prefixIdentifiers) {
        isProp.exp =
            processExpression(isProp.exp! as SimpleExpression, context);
      }
      exp = isProp.exp;
    }
  }
  if (exp != null) {
    context.helper(hResolveDynamicComponent);
    return createCallExp(hResolveDynamicComponent, [exp]);
  }
  return null;
}

String? _coreComponent(String tag) {
  switch (tag) {
    case 'Teleport':
    case 'teleport':
      return hTeleport;
    case 'Suspense':
    case 'suspense':
      return hSuspense;
    case 'KeepAlive':
    case 'keep-alive':
      return hKeepAlive;
    case 'BaseTransition':
    case 'base-transition':
      return hBaseTransition;
  }
  return null;
}

String? resolveSetupReference(String name, TransformContext context) {
  final bindings = context.bindingMetadata;
  if (bindings.isEmpty || bindings['__isScriptSetup'] == 'false') {
    return null;
  }
  final camelName = camelize(name);
  final pascalName = capitalize(camelName);
  String? checkType(String type) {
    if (bindings[name] == type) return name;
    if (bindings[camelName] == type) return camelName;
    if (bindings[pascalName] == type) return pascalName;
    return null;
  }

  final fromConst = checkType('setup-const') ??
      checkType('setup-reactive-const') ??
      checkType('literal-const');
  if (fromConst != null) {
    return context.inline ? fromConst : '\$setup[${jsonEncode(fromConst)}]';
  }
  final fromMaybeRef = checkType('setup-let') ??
      checkType('setup-ref') ??
      checkType('setup-maybe-ref');
  if (fromMaybeRef != null) {
    return context.inline
        ? '${context.helperString(hUnref)}($fromMaybeRef)'
        : '\$setup[${jsonEncode(fromMaybeRef)}]';
  }
  final fromProps = checkType('props');
  if (fromProps != null) {
    final obj = context.inline ? '__props' : '\$props';
    return '${context.helperString(hUnref)}($obj[${jsonEncode(fromProps)}])';
  }
  return null;
}
