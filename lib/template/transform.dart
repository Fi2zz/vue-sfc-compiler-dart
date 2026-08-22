// Port of compiler-core transform(): traverseNode / traverseChildren /
// createStructuralDirectiveTransform / createRootCodegen.
import 'js_nodes.dart';
import 'shared_utils.dart';
import 'transform_context.dart';
import 'tmpl_ast.dart';
import 'transforms/hoist_static.dart';

void transform(RootNode root, TransformOptions options) {
  final context = TransformContext(root, options);
  traverseNode(root, context);
  if (options.hoistStatic) {
    cacheStatic(root, context);
  }
  if (!options.ssr) {
    createRootCodegen(root, context);
  }
  root.helpers = context.helpers.keys.toSet();
  root.components = context.components.toList();
  root.directives = context.directives.toList();
  root.imports = context.imports;
  root.hoists = context.hoists;
  root.temps = context.temps;
  root.cached = context.cached;
  root.transformed = true;
}

void traverseChildren(TmplNode parent, TransformContext context) {
  var i = 0;
  final children = _childList(parent);
  void nodeRemoved() => i--;
  for (; i < children.length; i++) {
    final child = children[i];
    context.grandParent = context.parent;
    context.parent = parent;
    context.childIndex = i;
    context.onNodeRemoved = nodeRemoved;
    traverseNode(child, context);
  }
}

List<TmplNode> _childList(TmplNode node) => switch (node) {
      RootNode n => n.children,
      ElementNode n => n.children,
      IfBranchNode n => n.children,
      ForNode n => n.children,
      _ => throw StateError('no children: ${node.type}'),
    };

void traverseNode(TmplNode node, TransformContext context) {
  context.currentNode = node;
  final nodeTransforms = context.nodeTransforms;
  final exitFns = <void Function()>[];
  for (var i = 0; i < nodeTransforms.length; i++) {
    final onExit = nodeTransforms[i](node, context);
    if (onExit is List) {
      for (final fn in onExit) {
        exitFns.add(fn as void Function());
      }
    } else if (onExit is void Function()) {
      exitFns.add(onExit);
    }
    if (context.currentNode == null) {
      return;
    }
    node = context.currentNode!;
  }
  _traverseDown(node, context);
  context.currentNode = node;
  var i = exitFns.length;
  while (i-- > 0) {
    exitFns[i]();
  }
}

void _traverseDown(TmplNode node, TransformContext context) {
  switch (node.type) {
    case ntComment:
      if (!context.ssr) context.helper(hCreateComment);
    case ntInterpolation:
      if (!context.ssr) context.helper(hToDisplayString);
    case ntIf:
      final ifNode = node as IfNode;
      for (var i = 0; i < ifNode.branches.length; i++) {
        traverseNode(ifNode.branches[i], context);
      }
    case ntIfBranch:
    case ntFor:
    case ntElement:
    case ntRoot:
      traverseChildren(node, context);
  }
}

/// Port of createStructuralDirectiveTransform: [name] is String or RegExp.
NodeTransform createStructuralDirectiveTransform(
    Object name,
    Object? Function(TmplNode node, DirectiveNode dir, TransformContext ctx)
        fn) {
  bool matches(String n) =>
      name is String ? n == name : (name as RegExp).hasMatch(n);
  return (node, context) {
    if (node is! ElementNode) return null;
    final props = node.props;
    if (node.tagType == etTemplate && props.any(isVSlot)) return null;
    final exitFns = <void Function()>[];
    for (var i = 0; i < props.length; i++) {
      final prop = props[i];
      if (prop is DirectiveNode && matches(prop.name)) {
        props.removeAt(i);
        i--;
        final onExit = fn(node, prop, context);
        if (onExit is List) {
          for (final f in onExit) {
            exitFns.add(f as void Function());
          }
        } else if (onExit is void Function()) {
          exitFns.add(onExit);
        }
      }
    }
    return exitFns;
  };
}

void createRootCodegen(RootNode root, TransformContext context) {
  final children = root.children;
  if (children.length == 1) {
    final singleElementRootChild = _getSingleElementRoot(root);
    Object? codegenNode =
        singleElementRootChild is ElementNode
            ? singleElementRootChild.codegenNode
            : null;
    if (singleElementRootChild != null && codegenNode != null) {
      if (codegenNode is VNodeCall) {
        convertToBlock(codegenNode, context);
      }
      root.codegenNode = codegenNode;
    } else {
      root.codegenNode = children[0];
    }
  } else if (children.length > 1) {
    var patchFlag = 64;
    if (children.where((c) => c.type != ntComment).length == 1) {
      patchFlag |= 2048;
    }
    context.helper(hFragment);
    root.codegenNode = createVNodeCall(
        context,
        VNodeCallSpec(hFragment,
            children: root.children,
            patchFlag: patchFlag,
            isBlock: true));
  }
}

ElementNode? _getSingleElementRoot(RootNode root) {
  final children =
      root.children.where((x) => x.type != ntComment).toList();
  return children.length == 1 &&
          children[0].type == ntElement &&
          !isSlotOutlet(children[0])
      ? children[0] as ElementNode
      : null;
}
