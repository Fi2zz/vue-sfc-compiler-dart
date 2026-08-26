// Port of compiler-core transformElement.ts buildSlots + slot helpers.
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import '../tmpl_error_messages.dart';
import 'transform_utils.dart';
import 'v_for.dart';

final class SlotsBuildResult {
  Object slots; // JSObjectExpression | JSCallExpression
  bool hasDynamicSlots;
  SlotsBuildResult(this.slots, this.hasDynamicSlots);
}

JSFunctionExpression _buildClientSlotFn(
  Object? props,
  Object? vForExp,
  List<TmplNode> children,
  TmplLoc loc,
) {
  return JSFunctionExpression(
    props,
    children,
    newline: false,
    isSlot: true,
    loc: children.isNotEmpty ? children[0].loc : loc,
  );
}

final _defaultFallback = createSimpleExp('undefined');

class _BuildSlotsState {
  final List<JSProperty> slotsProperties = [];
  final List<Object?> dynamicSlots = [];
  bool hasDynamicSlots;
  bool hasTemplateSlots = false;
  bool hasNamedDefaultSlot = false;
  final List<TmplNode> implicitDefaultChildren = [];
  final Set<String> seenSlotNames = {};
  int conditionalBranchIndex = 0;
  _BuildSlotsState(this.hasDynamicSlots);
}

SlotsBuildResult buildSlots(ElementNode node, TransformContext context) {
  context.helper(hWithCtx);
  final children = node.children;
  final loc = node.loc;
  final st = _BuildSlotsState(
    context.scopes.vSlot > 0 || context.scopes.vFor > 0,
  );
  if (!context.ssr && context.prefixIdentifiers) {
    st.hasDynamicSlots =
        node.props.any(
          (prop) =>
              isVSlot(prop) &&
              (hasScopeRef((prop as DirectiveNode).arg, context.identifiers) ||
                  hasScopeRef(prop.exp, context.identifiers)),
        ) ||
        children.any((child) => hasScopeRef(child, context.identifiers));
  }
  final onComponentSlot = findDir(node, 'slot', true);
  if (onComponentSlot != null) {
    _buildOnComponentSlot(onComponentSlot, node, context, st, loc);
  }
  _buildTemplateSlots(node, context, st, onComponentSlot != null);
  if (onComponentSlot == null) {
    _buildDefaultSlot(node, context, st, loc);
  }
  return _assembleSlots(st, context, loc, node);
}

void _buildOnComponentSlot(
  DirectiveNode onComponentSlot,
  ElementNode node,
  TransformContext context,
  _BuildSlotsState st,
  TmplLoc loc,
) {
  final arg = onComponentSlot.arg;
  final exp = onComponentSlot.exp;
  if (arg != null && !isStaticExp(arg)) {
    st.hasDynamicSlots = true;
  }
  st.slotsProperties.add(
    createObjectProp(
      arg ?? createSimpleExp('default', true),
      _buildClientSlotFn(exp, null, node.children, loc),
    ),
  );
}

void _buildTemplateSlots(
  ElementNode node,
  TransformContext context,
  _BuildSlotsState st,
  bool hasOnComponentSlot,
) {
  final children = node.children;
  for (var i = 0; i < children.length; i++) {
    final slotElement = children[i];
    DirectiveNode? slotDir;
    if (!isTemplateNode(slotElement) ||
        (slotDir = findDir(slotElement, 'slot', true)) == null) {
      if (slotElement is! CommentNode) {
        st.implicitDefaultChildren.add(slotElement);
      }
      continue;
    }
    if (hasOnComponentSlot) {
      context.onError(
        TmplCompileError(
          37,
          'Slot usage mixed on component and template.',
          slotDir!.loc,
        ),
      );
      break;
    }
    st.hasTemplateSlots = true;
    _buildOneTemplateSlot(
      slotElement as ElementNode,
      slotDir!,
      context,
      st,
      i,
      children,
    );
  }
}

void _buildOneTemplateSlot(
  ElementNode slotElement,
  DirectiveNode slotDir,
  TransformContext context,
  _BuildSlotsState st,
  int index,
  List<TmplNode> children,
) {
  final slotChildren = slotElement.children;
  final slotLoc = slotElement.loc;
  final slotName = slotDir.arg ?? createSimpleExp('default', true);
  final slotProps = slotDir.exp;
  String? staticSlotName;
  if (isStaticExp(slotName)) {
    staticSlotName = (slotName as SimpleExpression).content;
  } else {
    st.hasDynamicSlots = true;
  }
  final vFor = findDir(slotElement, 'for');
  final slotFunction = _buildClientSlotFn(
    slotProps,
    vFor,
    slotChildren,
    slotLoc,
  );
  final vIf = findDir(slotElement, 'if');
  final vElse = findDir(slotElement, RegExp(r'^else(?:-if)?$'), true);
  if (vIf != null) {
    _slotWithIf(vIf, slotName, slotFunction, st);
  } else if (vElse != null) {
    _slotWithElse(vElse, slotName, slotFunction, st, context, children, index);
  } else if (vFor != null) {
    _slotWithFor(vFor, slotName, slotFunction, st, context);
  } else {
    _plainSlot(slotName, staticSlotName, slotFunction, st, context, slotDir);
  }
}

void _slotWithIf(
  DirectiveNode vIf,
  Object slotName,
  JSFunctionExpression slotFunction,
  _BuildSlotsState st,
) {
  st.hasDynamicSlots = true;
  st.dynamicSlots.add(
    JSConditionalExpression(
      vIf.exp!,
      _buildDynamicSlot(slotName, slotFunction, st.conditionalBranchIndex++),
      _defaultFallback,
    ),
  );
}

void _slotWithElse(
  DirectiveNode vElse,
  Object slotName,
  JSFunctionExpression slotFunction,
  _BuildSlotsState st,
  TransformContext context,
  List<TmplNode> children,
  int index,
) {
  var j = index;
  TmplNode? prev;
  while (j-- > 0) {
    final candidate = children[j];
    if (candidate is! CommentNode && isNonWhitespaceContent(candidate)) {
      prev = candidate;
      break;
    }
  }
  if (prev != null &&
      isTemplateNode(prev) &&
      findDir(prev, RegExp(r'^(?:else-)?if$')) != null) {
    _attachElseSlot(vElse, slotName, slotFunction, st);
  } else {
    context.onError(
      TmplCompileError(
        30,
        'v-else/v-else-if has no adjacent v-if or v-else-if.',
        vElse.loc,
      ),
    );
  }
}

void _attachElseSlot(
  DirectiveNode vElse,
  Object slotName,
  JSFunctionExpression slotFunction,
  _BuildSlotsState st,
) {
  var conditional = st.dynamicSlots.last as JSConditionalExpression;
  while (conditional.alternate is JSConditionalExpression) {
    conditional = conditional.alternate as JSConditionalExpression;
  }
  conditional.alternate = vElse.exp != null
      ? JSConditionalExpression(
          vElse.exp!,
          _buildDynamicSlot(
            slotName,
            slotFunction,
            st.conditionalBranchIndex++,
          ),
          _defaultFallback,
        )
      : _buildDynamicSlot(slotName, slotFunction, st.conditionalBranchIndex++);
}

void _slotWithFor(
  DirectiveNode vFor,
  Object slotName,
  JSFunctionExpression slotFunction,
  _BuildSlotsState st,
  TransformContext context,
) {
  st.hasDynamicSlots = true;
  final parseResult = vFor.forParseResult;
  if (parseResult != null) {
    finalizeForParseResult(parseResult, context);
    context.helper(hRenderList);
    st.dynamicSlots.add(
      createCallExp(hRenderList, [
        parseResult.source,
        JSFunctionExpression(
          createForLoopParams(parseResult),
          _buildDynamicSlot(slotName, slotFunction, null),
          newline: true,
        ),
      ]),
    );
  } else {
    context.onError(TmplCompileError(32, tmplErrorMessage(32), vFor.loc));
  }
}

void _plainSlot(
  Object slotName,
  String? staticSlotName,
  JSFunctionExpression slotFunction,
  _BuildSlotsState st,
  TransformContext context,
  DirectiveNode slotDir,
) {
  if (staticSlotName != null) {
    if (st.seenSlotNames.contains(staticSlotName)) {
      context.onError(TmplCompileError(38, tmplErrorMessage(38), slotDir.loc));
      return;
    }
    st.seenSlotNames.add(staticSlotName);
    if (staticSlotName == 'default') {
      st.hasNamedDefaultSlot = true;
    }
  }
  st.slotsProperties.add(createObjectProp(slotName, slotFunction));
}

void _buildDefaultSlot(
  ElementNode node,
  TransformContext context,
  _BuildSlotsState st,
  TmplLoc loc,
) {
  JSProperty buildDefaultSlotProperty(Object? props, List<TmplNode> children2) {
    final fn = _buildClientSlotFn(props, null, children2, loc);
    return createObjectProp('default', fn);
  }

  if (!st.hasTemplateSlots) {
    st.slotsProperties.add(buildDefaultSlotProperty(null, node.children));
  } else if (st.implicitDefaultChildren.isNotEmpty &&
      st.implicitDefaultChildren.any(isNonWhitespaceContent)) {
    if (st.hasNamedDefaultSlot) {
      context.onError(
        TmplCompileError(
          39,
          tmplErrorMessage(39),
          st.implicitDefaultChildren[0].loc,
        ),
      );
    } else {
      st.slotsProperties.add(
        buildDefaultSlotProperty(null, st.implicitDefaultChildren),
      );
    }
  }
}

SlotsBuildResult _assembleSlots(
  _BuildSlotsState st,
  TransformContext context,
  TmplLoc loc,
  ElementNode node,
) {
  final slotFlag = st.hasDynamicSlots
      ? 2
      : _hasForwardedSlots(node.children)
      ? 3
      : 1;
  final properties = [
    ...st.slotsProperties,
    createObjectProp(
      '_',
      createSimpleExp('$slotFlag /* ${slotFlagsText[slotFlag]} */', false),
    ),
  ];
  Object slots = createObjectExp(properties, loc);
  if (st.dynamicSlots.isNotEmpty) {
    context.helper(hCreateSlots);
    slots = createCallExp(hCreateSlots, [
      slots,
      createArrayExp(st.dynamicSlots),
    ]);
  }
  return SlotsBuildResult(slots, st.hasDynamicSlots);
}

JSObjectExpression _buildDynamicSlot(
  Object name,
  JSFunctionExpression fn,
  int? index,
) {
  final props = [createObjectProp('name', name), createObjectProp('fn', fn)];
  if (index != null) {
    props.add(createObjectProp('key', createSimpleExp('$index', true)));
  }
  return createObjectExp(props);
}

bool _hasForwardedSlots(List<TmplNode> children) {
  for (final child in children) {
    switch (child) {
      case ElementNode n:
        // 官方：child.tagType === ElementTypes.SLOT（<slot> 出口即转发）
        if (n.tagType == etSlot || _hasForwardedSlots(n.children)) {
          return true;
        }
      case IfNode n:
        if (n.branches.any((b) => _hasForwardedSlots(b.children))) {
          return true;
        }
      case IfBranchNode n:
        if (_hasForwardedSlots(n.children)) return true;
      case ForNode n:
        if (_hasForwardedSlots(n.children)) return true;
      default:
        break;
    }
  }
  return false;
}
