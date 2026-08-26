// JS codegen node model mirroring @vue/compiler-core codegen node shapes.
// Helper identity: official uses Symbols; we use the runtime helper NAME as
// the key (names are unique), so helperNameMap is the identity map and
// equality checks on callees/tags are plain string comparisons.

import 'tmpl_ast.dart';

// Official helper names (values of helperNameMap).
const hFragment = 'Fragment';
const hTeleport = 'Teleport';
const hSuspense = 'Suspense';
const hKeepAlive = 'KeepAlive';
const hBaseTransition = 'BaseTransition';
const hOpenBlock = 'openBlock';
const hCreateBlock = 'createBlock';
const hCreateElementBlock = 'createElementBlock';
const hCreateVNode = 'createVNode';
const hCreateElementVNode = 'createElementVNode';
const hCreateComment = 'createCommentVNode';
const hCreateText = 'createTextVNode';
const hCreateStatic = 'createStaticVNode';
const hResolveComponent = 'resolveComponent';
const hResolveDynamicComponent = 'resolveDynamicComponent';
const hResolveDirective = 'resolveDirective';
const hResolveFilter = 'resolveFilter';
const hWithDirectives = 'withDirectives';
const hRenderList = 'renderList';
const hRenderSlot = 'renderSlot';
const hCreateSlots = 'createSlots';
const hToDisplayString = 'toDisplayString';
const hMergeProps = 'mergeProps';
const hNormalizeClass = 'normalizeClass';
const hNormalizeStyle = 'normalizeStyle';
const hNormalizeProps = 'normalizeProps';
const hGuardReactiveProps = 'guardReactiveProps';
const hToHandlers = 'toHandlers';
const hCamelize = 'camelize';
const hCapitalize = 'capitalize';
const hToHandlerKey = 'toHandlerKey';
const hSetBlockTracking = 'setBlockTracking';
const hPushScopeId = 'pushScopeId';
const hPopScopeId = 'popScopeId';
const hWithCtx = 'withCtx';
const hUnref = 'unref';
const hIsRef = 'isRef';
const hWithMemo = 'withMemo';
const hIsMemoSame = 'isMemoSame';
// DOM runtime helpers.
const hVModelText = 'vModelText';
const hVModelCheckbox = 'vModelCheckbox';
const hVModelRadio = 'vModelRadio';
const hVModelSelect = 'vModelSelect';
const hVModelDynamic = 'vModelDynamic';
const hVOnWithModifiers = 'withModifiers';
const hVOnWithKeys = 'withKeys';
const hVShow = 'vShow';
const hTransition = 'Transition';
const hTransitionGroup = 'TransitionGroup';

/// Port of official PatchFlagNames (dev comments).
/// Official helperNameMap values (core + DOM registerRuntimeHelpers).
/// Strings equal to these are printed as `_name` in codegen (Symbol identity
/// in official is modeled by helper-name strings in this port).
const helperNames = {
  'Fragment',
  'Teleport',
  'Suspense',
  'KeepAlive',
  'BaseTransition',
  'openBlock',
  'createBlock',
  'createElementBlock',
  'createVNode',
  'createElementVNode',
  'createCommentVNode',
  'createTextVNode',
  'createStaticVNode',
  'resolveComponent',
  'resolveDynamicComponent',
  'resolveDirective',
  'resolveFilter',
  'withDirectives',
  'renderList',
  'renderSlot',
  'createSlots',
  'toDisplayString',
  'mergeProps',
  'normalizeClass',
  'normalizeStyle',
  'normalizeProps',
  'guardReactiveProps',
  'toHandlers',
  'camelize',
  'capitalize',
  'toHandlerKey',
  'setBlockTracking',
  'pushScopeId',
  'popScopeId',
  'withCtx',
  'unref',
  'isRef',
  'withMemo',
  'isMemoSame',
  'vModelRadio',
  'vModelCheckbox',
  'vModelText',
  'vModelSelect',
  'vModelDynamic',
  'withModifiers',
  'withKeys',
  'vShow',
  'Transition',
  'TransitionGroup',
};

const patchFlagNames = <int, String>{
  1: 'TEXT',
  2: 'CLASS',
  4: 'STYLE',
  8: 'PROPS',
  16: 'FULL_PROPS',
  32: 'NEED_HYDRATION',
  64: 'STABLE_FRAGMENT',
  128: 'KEYED_FRAGMENT',
  256: 'UNKEYED_FRAGMENT',
  512: 'NEED_PATCH',
  1024: 'DYNAMIC_SLOTS',
  2048: 'DEV_ROOT_FRAGMENT',
  -1: 'CACHED',
  -2: 'BAIL',
};

const slotFlagsText = <int, String>{1: 'STABLE', 2: 'DYNAMIC', 3: 'FORWARDED'};

/// Minimal host interface so codegen factories can register helpers without
/// depending on the concrete TransformContext (avoids import cycles).
abstract class HelperHost {
  void helper(String name);
  void removeHelper(String name);
  bool get inSSR;
}

abstract class CodegenNode {
  int get type;
  TmplLoc get loc;
}

final class VNodeCall extends CodegenNode {
  @override
  final int type = ntVNodeCall;
  Object tag; // String literal | helper name | JSCallExpression
  Object? props; // String | JSObjectExpression | JSCallExpression
  Object? children; // List<TmplNode> | TextCallNode | JSObjectExpression
  int? patchFlag;
  Object? dynamicProps; // String | hoisted SimpleExpression
  JSArrayExpression? directives;
  bool isBlock;
  bool disableTracking;
  bool isComponent;
  @override
  TmplLoc loc;
  VNodeCall(VNodeCallSpec s)
    : tag = s.tag,
      props = s.props,
      children = s.children,
      patchFlag = s.patchFlag,
      dynamicProps = s.dynamicProps,
      directives = s.directives,
      isBlock = s.isBlock,
      disableTracking = s.disableTracking,
      isComponent = s.isComponent,
      loc = s.loc ?? locStub();
}

/// Parameter object for createVNodeCall (official signature has 11 params).
final class VNodeCallSpec {
  Object tag;
  Object? props;
  Object? children;
  int? patchFlag;
  Object? dynamicProps; // String | hoisted SimpleExpression
  JSArrayExpression? directives;
  bool isBlock;
  bool disableTracking;
  bool isComponent;
  TmplLoc? loc;
  VNodeCallSpec(
    this.tag, {
    this.props,
    this.children,
    this.patchFlag,
    this.dynamicProps,
    this.directives,
    this.isBlock = false,
    this.disableTracking = false,
    this.isComponent = false,
    this.loc,
  });
}

final class JSCallExpression extends CodegenNode {
  @override
  final int type = ntJSCallExpression;
  Object callee; // String identifier | helper name
  List<Object?> arguments;
  @override
  TmplLoc loc;
  JSCallExpression(this.callee, this.arguments, [TmplLoc? loc])
    : loc = loc ?? locStub();
}

final class JSObjectExpression extends CodegenNode {
  @override
  final int type = ntJSObjectExpression;
  List<JSProperty> properties;
  @override
  TmplLoc loc;
  JSObjectExpression(this.properties, [TmplLoc? loc]) : loc = loc ?? locStub();
}

final class JSProperty extends CodegenNode {
  @override
  final int type = ntJSProperty;
  Object key; // SimpleExpression | CompoundExpression (dynamic key)
  Object? value;
  @override
  TmplLoc loc = _propLoc;
  JSProperty(Object key, this.value)
    : key = key is String ? createSimpleExp(key, true) : key;
  static final _propLoc = locStub();
}

final class JSArrayExpression extends CodegenNode {
  @override
  final int type = ntJSArrayExpression;
  List<Object?> elements;
  @override
  TmplLoc loc;
  JSArrayExpression(this.elements, [TmplLoc? loc]) : loc = loc ?? locStub();
}

final class JSFunctionExpression extends CodegenNode {
  @override
  final int type = ntJSFunctionExpression;
  Object? params; // List<Object?> | single node
  Object? returns;
  Object? body;
  bool newline;
  bool isSlot;
  bool isNonScopedSlot = false;
  @override
  TmplLoc loc;
  JSFunctionExpression(
    this.params,
    this.returns, {
    this.newline = false,
    this.isSlot = false,
    TmplLoc? loc,
  }) : loc = loc ?? locStub();
}

final class JSConditionalExpression extends CodegenNode {
  @override
  final int type = ntJSConditionalExpression;
  Object test;
  Object consequent;
  Object alternate;
  bool newline;
  @override
  TmplLoc loc = _condLoc;
  JSConditionalExpression(
    this.test,
    this.consequent,
    this.alternate, {
    this.newline = true,
  });
  static final _condLoc = locStub();
}

final class JSCacheExpression extends CodegenNode {
  @override
  final int type = ntJSCacheExpression;
  int index;
  Object? value;
  bool needPauseTracking;
  bool inVOnce;
  bool needArraySpread = false;
  @override
  TmplLoc loc = _cacheLoc;
  JSCacheExpression(
    this.index,
    this.value, {
    this.needPauseTracking = false,
    this.inVOnce = false,
  });
  static final _cacheLoc = locStub();
}

final class JSBlockStatement extends CodegenNode {
  @override
  final int type = ntJSBlockStatement;
  List<Object?> body;
  @override
  TmplLoc loc = _blockLoc;
  JSBlockStatement(this.body);
  static final _blockLoc = locStub();
}

final class JSTemplateLiteral extends CodegenNode {
  @override
  final int type = ntJSTemplateLiteral;
  List<Object?> elements;
  @override
  TmplLoc loc = _tplLoc;
  JSTemplateLiteral(this.elements);
  static final _tplLoc = locStub();
}

final class JSIfStatement extends CodegenNode {
  @override
  final int type = ntJSIfStatement;
  Object test;
  Object consequent;
  Object? alternate;
  @override
  TmplLoc loc = _ifLoc;
  JSIfStatement(this.test, this.consequent, [this.alternate]);
  static final _ifLoc = locStub();
}

final class JSAssignmentExpression extends CodegenNode {
  @override
  final int type = ntJSAssignmentExpression;
  Object left;
  Object right;
  @override
  TmplLoc loc = _assignLoc;
  JSAssignmentExpression(this.left, this.right);
  static final _assignLoc = locStub();
}

final class JSSequenceExpression extends CodegenNode {
  @override
  final int type = ntJSSequenceExpression;
  List<Object?> expressions;
  @override
  TmplLoc loc = _seqLoc;
  JSSequenceExpression(this.expressions);
  static final _seqLoc = locStub();
}

final class JSReturnStatement extends CodegenNode {
  @override
  final int type = ntJSReturnStatement;
  Object? returns;
  @override
  TmplLoc loc = _retLoc;
  JSReturnStatement(this.returns);
  static final _retLoc = locStub();
}

// --- Factories mirroring official ast.ts helpers ---

SimpleExpression createSimpleExp(
  String content, [
  bool isStatic = false,
  TmplLoc? loc,
  int constType = ctNotConstant,
]) {
  return SimpleExpression(
    content,
    isStatic,
    loc ?? locStub(),
    isStatic ? ctCanStringify : constType,
  );
}

CompoundExpression createCompoundExp(List<Object?> children, [TmplLoc? loc]) {
  return CompoundExpression(children, loc ?? locStub());
}

JSCallExpression createCallExp(
  Object callee, [
  List<Object?> args = const [],
  TmplLoc? loc,
]) {
  return JSCallExpression(callee, args, loc);
}

String getVNodeHelper(bool ssr, bool isComponent) {
  return ssr || isComponent ? hCreateVNode : hCreateElementVNode;
}

String getVNodeBlockHelper(bool ssr, bool isComponent) {
  return ssr || isComponent ? hCreateBlock : hCreateElementBlock;
}

VNodeCall createVNodeCall(HelperHost? context, VNodeCallSpec s) {
  if (context != null) {
    if (s.isBlock) {
      context.helper(hOpenBlock);
      context.helper(getVNodeBlockHelper(context.inSSR, s.isComponent));
    } else {
      context.helper(getVNodeHelper(context.inSSR, s.isComponent));
    }
    if (s.directives != null) {
      context.helper(hWithDirectives);
    }
  }
  return VNodeCall(s);
}

void convertToBlock(VNodeCall node, HelperHost context) {
  if (!node.isBlock) {
    node.isBlock = true;
    context.removeHelper(getVNodeHelper(context.inSSR, node.isComponent));
    context.helper(hOpenBlock);
    context.helper(getVNodeBlockHelper(context.inSSR, node.isComponent));
  }
}

JSArrayExpression createArrayExp(List<Object?> elements, [TmplLoc? loc]) {
  return JSArrayExpression(elements, loc);
}

JSObjectExpression createObjectExp(
  List<JSProperty> properties, [
  TmplLoc? loc,
]) {
  return JSObjectExpression(properties, loc);
}

JSProperty createObjectProp(Object key, Object? value) {
  return JSProperty(key, value);
}
