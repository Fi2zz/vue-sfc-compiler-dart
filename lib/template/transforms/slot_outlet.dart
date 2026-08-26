// Port of compiler-core transformSlotOutlet + processSlotOutlet.
import 'dart:convert';

import '../js_nodes.dart';
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import 'transform_element.dart';
import 'transform_expression.dart';

Object? transformSlotOutlet(TmplNode node, TransformContext context) {
  if (!isSlotOutlet(node)) return null;
  final el = node as ElementNode;
  final children = el.children;
  final loc = el.loc;
  final result = _processSlotOutlet(el, context);
  final slotArgs = <Object?>[
    context.prefixIdentifiers ? '_ctx.\$slots' : '\$slots',
    result.$1,
    '{}',
    'undefined',
    'true',
  ];
  var expectedLen = 2;
  if (result.$2 != null) {
    slotArgs[2] = result.$2;
    expectedLen = 3;
  }
  if (children.isNotEmpty) {
    slotArgs[3] = JSFunctionExpression(
      <Object?>[],
      children,
      newline: false,
      loc: loc,
    );
    expectedLen = 4;
  }
  if (context.scopeId != null && !context.slotted) {
    expectedLen = 5;
  }
  slotArgs.length = expectedLen;
  context.helper(hRenderSlot);
  el.codegenNode = createCallExp(hRenderSlot, slotArgs, loc);
  return null;
}

(Object, Object?) _processSlotOutlet(
  ElementNode node,
  TransformContext context,
) {
  Object slotName = '"default"';
  Object? slotProps;
  final nonNameProps = <TmplNode>[];
  for (final p in node.props) {
    if (p is AttributeNode) {
      if (p.value != null) {
        if (p.name == 'name') {
          slotName = jsonEncode(p.value!.content);
        } else {
          p.name = camelize(p.name);
          nonNameProps.add(p);
        }
      }
    } else if (p is DirectiveNode) {
      if (p.name == 'bind' && isStaticArgOf(p.arg, 'name')) {
        if (p.exp != null) {
          slotName = p.exp!;
        } else if (p.arg is SimpleExpression) {
          final name = camelize((p.arg as SimpleExpression).content);
          p.exp = createSimpleExp(name, false, p.arg!.loc);
          if (context.prefixIdentifiers) {
            p.exp = processExpression(p.exp! as SimpleExpression, context);
          }
          slotName = p.exp!;
        }
      } else {
        if (p.name == 'bind' &&
            p.arg is SimpleExpression &&
            (p.arg as SimpleExpression).static_) {
          (p.arg as SimpleExpression).content = camelize(
            (p.arg as SimpleExpression).content,
          );
        }
        nonNameProps.add(p);
      }
    }
  }
  if (nonNameProps.isNotEmpty) {
    final built = buildProps(
      node,
      context,
      props: nonNameProps,
      isComponent: false,
      isDynamicComponent: false,
    );
    slotProps = built.props;
    if (built.directives.isNotEmpty) {
      context.onError(
        TmplCompileError(
          36,
          'Runtime directives are not allowed on <slot>.',
          built.directives[0].loc,
        ),
      );
    }
  }
  return (slotName, slotProps);
}
