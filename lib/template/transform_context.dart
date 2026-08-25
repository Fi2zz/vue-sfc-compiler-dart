// Port of compiler-core createTransformContext + transform().
import 'js_nodes.dart';
import 'tmpl_ast.dart';

/// Result of a directive transform (official DirectiveTransformResult).
final class DirTransformResult {
  List<JSProperty> props;
  Object? needRuntime; // true | helper name String
  DirTransformResult(this.props, [this.needRuntime]);
}

typedef NodeTransform = Object? Function(TmplNode node, TransformContext ctx);
typedef DirectiveTransform = DirTransformResult Function(
    DirectiveNode dir, ElementNode node, TransformContext ctx);
typedef TransformHoist = void Function(
    List<TmplNode> children, TransformContext ctx, TmplNode parent);

final class TmplCompileError implements Exception {
  final int code;
  final String message;
  final TmplLoc? loc;
  TmplCompileError(this.code, this.message, [this.loc]);
  @override
  String toString() => 'Vue Template Compile Error $code: $message';
}

final class TransformOptions {
  String filename = '';
  bool prefixIdentifiers = false;
  bool hoistStatic = false;
  bool hmr = false;
  bool cacheHandlers = false;
  List<NodeTransform> nodeTransforms = [];
  Map<String, DirectiveTransform> directiveTransforms = {};
  TransformHoist? transformHoist;
  String? Function(String tag)? isBuiltInComponent;
  bool Function(String tag)? isCustomElement;
  List<String> expressionPlugins = [];
  String? scopeId;
  bool slotted = true;
  bool ssr = false;
  bool inSSR = false;
  String ssrCssVars = '';
  Map<String, String> bindingMetadata = const {};
  bool inline = false;
  bool isTS = false;
  void Function(TmplCompileError e)? onError;
  void Function(TmplCompileError e)? onWarn;
  String? selfName;
}

final class Scopes {
  int vFor = 0;
  int vSlot = 0;
  int vPre = 0;
  int vOnce = 0;
}

final class TransformContext implements HelperHost {
  final TransformOptions options;
  RootNode root;
  // state
  final Map<String, int> helpers = {};
  final Set<String> components = {};
  final Set<String> directives = {};
  final List<Object?> hoists = [];
  final List<Object?> imports = [];
  final List<JSCacheExpression?> cached = [];
  final Map<TmplNode, int> constantCache = {};
  int temps = 0;
  final Map<String, int> identifiers = {};
  final Scopes scopes = Scopes();
  TmplNode? parent;
  TmplNode? grandParent;
  TmplNode? currentNode;
  int childIndex = 0;
  bool inVOnce = false;
  void Function() onNodeRemoved = () {};

  TransformContext(this.root, this.options) {
    currentNode = root;
  }

  String? get selfName => options.selfName;
  bool get prefixIdentifiers => options.prefixIdentifiers;
  bool get hoistStatic => options.hoistStatic;
  bool get cacheHandlers => options.cacheHandlers;
  bool get ssr => options.ssr;
  @override
  bool get inSSR => options.inSSR;
  bool get inline => options.inline;
  bool get isTS => options.isTS;
  bool get slotted => options.slotted;
  String? get scopeId => options.scopeId;
  Map<String, String> get bindingMetadata => options.bindingMetadata;
  List<NodeTransform> get nodeTransforms => options.nodeTransforms;
  Map<String, DirectiveTransform> get directiveTransforms =>
      options.directiveTransforms;
  TransformHoist? get transformHoist => options.transformHoist;

  void onError(TmplCompileError e) {
    final fn = options.onError;
    if (fn != null) {
      fn(e);
    } else {
      throw e;
    }
  }

  void onWarn(TmplCompileError e) => options.onWarn?.call(e);

  @override
  void helper(String name) => helpers[name] = (helpers[name] ?? 0) + 1;

  @override
  void removeHelper(String name) {
    final count = helpers[name];
    if (count != null) {
      if (count - 1 == 0) {
        helpers.remove(name);
      } else {
        helpers[name] = count - 1;
      }
    }
  }
}

extension TransformContextMethods on TransformContext {
  String helperString(String name) {
    helper(name);
    return '_$name';
  }

  void replaceNode(TmplNode node) {
    if (currentNode == null) {
      throw StateError('Node being replaced is already removed.');
    }
    if (parent == null) {
      throw StateError('Cannot replace root node.');
    }
    _childrenOf(parent!)[childIndex] = node;
    currentNode = node;
  }

  void removeNode([TmplNode? node]) {
    if (parent == null) {
      throw StateError('Cannot remove root node.');
    }
    final list = _childrenOf(parent!);
    final removalIndex = node != null
        ? list.indexOf(node)
        : currentNode != null
            ? childIndex
            : -1;
    if (removalIndex < 0) {
      throw StateError('node being removed is not a child of current parent');
    }
    if (node == null || identical(node, currentNode)) {
      currentNode = null;
      onNodeRemoved();
    } else {
      if (childIndex > removalIndex) {
        childIndex--;
        onNodeRemoved();
      }
    }
    list.removeAt(removalIndex);
  }

  void addIdentifiers(Object? exp) =>
      _forEachId(exp, (id) => identifiers[id] = (identifiers[id] ?? 0) + 1);

  void removeIdentifiers(Object? exp) =>
      _forEachId(exp, (id) => identifiers[id] = (identifiers[id] ?? 0) - 1);

  SimpleExpression hoist(Object? exp) {
    if (exp is String) exp = createSimpleExp(exp);
    hoists.add(exp);
    // 官方：引用标识符携带被提升表达式的 loc（映射到元素位置）。
    final loc = switch (exp) {
      SimpleExpression e => e.loc,
      TmplNode n => n.loc,
      CodegenNode n => n.loc,
      _ => null,
    };
    final identifier =
        createSimpleExp('_hoisted_${hoists.length}', false, loc, ctCanHoist);
    identifier.hoisted = exp;
    return identifier;
  }

  JSCacheExpression cache(Object? exp,
      [bool isVNode = false, bool inVOnce = false]) {
    final cacheExp = JSCacheExpression(cached.length, exp,
        needPauseTracking: isVNode, inVOnce: inVOnce);
    cached.add(cacheExp);
    return cacheExp;
  }

  void _forEachId(Object? exp, void Function(String id) fn) {
    if (exp is String) {
      fn(exp);
    } else if (exp is SimpleExpression) {
      final ids = exp.identifiers;
      if (ids != null) {
        ids.forEach(fn);
      } else {
        fn(exp.content);
      }
    } else if (exp is CompoundExpression) {
      exp.identifiers?.forEach(fn);
    }
  }
}

List<TmplNode> _childrenOf(TmplNode node) {
  return switch (node) {
    RootNode n => n.children,
    ElementNode n => n.children,
    IfBranchNode n => n.children,
    ForNode n => n.children,
    _ => throw StateError('node has no children list: ${node.type}'),
  };
}

/// Port of official isBuiltInComponent passthrough (option or NOOP).
String? builtInComponentOf(TransformContext ctx, String tag) {
  final fn = ctx.options.isBuiltInComponent;
  return fn == null ? null : fn(tag);
}

bool customElementOf(TransformContext ctx, String tag) {
  final fn = ctx.options.isCustomElement;
  return fn == null ? false : fn(tag);
}
