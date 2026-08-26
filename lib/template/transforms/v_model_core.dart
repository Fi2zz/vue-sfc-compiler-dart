// Port of compiler-core transformModel (base; DOM layer extends it).
import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import '../tmpl_error_messages.dart';
import 'transform_expression.dart';
import 'transform_utils.dart';

DirTransformResult transformModelCore(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
) {
  final dirExp = dir.exp;
  final arg = dir.arg;
  if (dirExp == null) {
    context.onError(
      TmplCompileError(41, 'v-model is missing expression.', dir.loc),
    );
    return DirTransformResult([]);
  }
  // 官方：exp.type === 4 ? exp.content : rawExp——transformExpression 可能
  // 已把 dir.exp 替换成 CompoundExpression，此时按原始 source 处理。
  final rawExp = dirExp.loc.source.trim();
  final expString = dirExp is SimpleExpression ? dirExp.content : rawExp;
  final bindingType = context.bindingMetadata[rawExp];
  if (bindingType == 'props' || bindingType == 'props-aliased') {
    context.onError(TmplCompileError(44, tmplErrorMessage(44), dirExp.loc));
    return DirTransformResult([]);
  }
  final maybeRef =
      context.inline &&
      (bindingType == 'setup-let' ||
          bindingType == 'setup-ref' ||
          bindingType == 'setup-maybe-ref');
  if (expString.trim().isEmpty ||
      (!isMemberExpressionOf(dirExp, context) && !maybeRef)) {
    context.onError(TmplCompileError(42, tmplErrorMessage(42), dirExp.loc));
    return DirTransformResult([]);
  }
  if (context.prefixIdentifiers &&
      isSimpleIdentifier(expString) &&
      (context.identifiers[expString] ?? 0) != 0) {
    context.onError(TmplCompileError(43, tmplErrorMessage(43), dirExp.loc));
    return DirTransformResult([]);
  }
  final props = _modelProps(
    dir,
    node,
    context,
    dirExp,
    arg,
    rawExp,
    bindingType,
    maybeRef,
  );
  return DirTransformResult(props);
}

List<JSProperty> _modelProps(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
  TmplNode exp,
  Object? arg,
  String rawExp,
  String? bindingType,
  bool maybeRef,
) {
  final Object propName = arg ?? createSimpleExp('modelValue', true);
  final Object eventName = arg != null
      ? (isStaticExp(arg)
            ? 'onUpdate:${camelize((arg as SimpleExpression).content)}'
            : createCompoundExp(['"onUpdate:" + ', arg]))
      : 'onUpdate:modelValue';
  final assignmentExp = _modelAssignment(
    context,
    exp,
    rawExp,
    bindingType,
    maybeRef,
  );
  final props = [
    createObjectProp(propName, dir.exp),
    createObjectProp(eventName, assignmentExp),
  ];
  if (context.prefixIdentifiers &&
      !context.inVOnce &&
      context.cacheHandlers &&
      !hasScopeRef(exp, context.identifiers)) {
    props[1].value = context.cache(props[1].value);
  }
  _maybeModelModifiers(dir, node, context, arg, props);
  return props;
}

Object _modelAssignment(
  TransformContext context,
  TmplNode exp,
  String rawExp,
  String? bindingType,
  bool maybeRef,
) {
  final eventArg = context.isTS ? '(\$event: any)' : '\$event';
  if (maybeRef) {
    if (bindingType == 'setup-ref') {
      return createCompoundExp([
        '$eventArg => ((',
        createSimpleExp(rawExp, false, exp.loc),
        ').value = \$event)',
      ]);
    }
    final altAssignment = bindingType == 'setup-let'
        ? '$rawExp = \$event'
        : 'null';
    return createCompoundExp([
      '$eventArg => (${context.helperString(hIsRef)}($rawExp) ? (',
      createSimpleExp(rawExp, false, exp.loc),
      ').value = \$event : $altAssignment)',
    ]);
  }
  return createCompoundExp(['$eventArg => ((', exp, ') = \$event)']);
}

void _maybeModelModifiers(
  DirectiveNode dir,
  ElementNode node,
  TransformContext context,
  Object? arg,
  List<JSProperty> props,
) {
  if (dir.modifiers.isEmpty || node.tagType != etComponent) return;
  final modifiers = dir.modifiers
      .map((m) => m.content)
      .map((m) => '${isSimpleIdentifier(m) ? m : _jsQuote(m)}: true')
      .join(', ');
  final Object modifiersKey = arg != null
      ? (isStaticExp(arg)
            ? '${(arg as SimpleExpression).content}Modifiers'
            : createCompoundExp([arg, ' + "Modifiers"']))
      : 'modelModifiers';
  props.add(
    createObjectProp(
      modifiersKey,
      createSimpleExp('{ $modifiers }', false, dir.loc, ctCanHoist),
    ),
  );
}

String _jsQuote(String s) {
  final escaped = s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  return '"$escaped"';
}
