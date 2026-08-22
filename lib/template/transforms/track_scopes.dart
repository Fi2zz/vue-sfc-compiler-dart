// Ports of compiler-core trackSlotScopes / trackVForSlotScopes.
import '../shared_utils.dart';
import '../transform_context.dart';
import '../tmpl_ast.dart';
import 'v_for.dart';

Object? trackSlotScopes(TmplNode node, TransformContext context) {
  if (node is ElementNode &&
      (node.tagType == etComponent || node.tagType == etTemplate)) {
    final vSlot = findDir(node, 'slot');
    if (vSlot != null) {
      final slotProps = vSlot.exp;
      if (context.prefixIdentifiers && slotProps != null) {
        context.addIdentifiers(slotProps);
      }
      context.scopes.vSlot++;
      return () {
        if (context.prefixIdentifiers && slotProps != null) {
          context.removeIdentifiers(slotProps);
        }
        context.scopes.vSlot--;
      };
    }
  }
  return null;
}

Object? trackVForSlotScopes(TmplNode node, TransformContext context) {
  if (isTemplateNode(node) && (node as ElementNode).props.any(isVSlot)) {
    final vFor = findDir(node, 'for');
    final result = vFor?.forParseResult;
    if (result != null) {
      finalizeForParseResult(result, context);
      final value = result.value;
      final key = result.key;
      final index = result.index;
      if (value != null) context.addIdentifiers(value);
      if (key != null) context.addIdentifiers(key);
      if (index != null) context.addIdentifiers(index);
      return () {
        if (value != null) context.removeIdentifiers(value);
        if (key != null) context.removeIdentifiers(key);
        if (index != null) context.removeIdentifiers(index);
      };
    }
  }
  return null;
}
