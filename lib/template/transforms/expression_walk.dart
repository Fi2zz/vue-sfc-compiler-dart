// Port of compiler-core babelUtils.ts walkIdentifiers + scope tracking onto
// the tree-sitter TS AST (AstNode). Offsets are converted to UTF-16 char
// offsets relative to the raw expression by the caller via SrcView.
import '../../ts_parser.dart';

import '../../script/src_view.dart';

final class WalkedIdent {
  // update 表达式参数会扩写区间（官方 id.start/end 延展），故可变。
  int startChar; // UTF-16 offset within the wrapped source
  int endChar;
  final String name;
  String? prefix; // 'name: ' for shorthand object properties
  bool isConstant = false;
  String? rewritten; // rewritten name when prefixed
  WalkedIdent(this.startChar, this.endChar, this.name);
}

/// Scope-aware identifier map mirroring Object.create(context.identifiers):
/// lookups fall through to template-scope identifiers, own keys are tracked.
final class KnownIds {
  final Map<String, int> parent;
  final Map<String, int> own = {};
  KnownIds(this.parent);

  bool contains(String name) => (own[name] ?? parent[name] ?? 0) != 0;

  void mark(String name) => own[name] = (own[name] ?? 0) + 1;

  void unmark(String name) {
    final count = (own[name] ?? 0) - 1;
    if (count <= 0) {
      own.remove(name);
    } else {
      own[name] = count;
    }
  }

  List<String> ownKeys() => own.keys.toList();
}

typedef OnIdentifier = void Function(WalkedIdent id, AstNode? parent,
    bool isReferenced, bool isLocal,
    {bool destructureAssignment});

/// tree-sitter type containers whose subtrees are TS type space (skipped).
bool _isTsTypeSpace(String type) {
  if (type.startsWith('type')) return true;
  const extra = {
    'predefined_type',
    'generic_type',
    'union_type',
    'intersection_type',
    'array_type',
    'function_type',
    'object_type',
    'tuple_type',
    'literal_type',
    'parenthesized_type',
    'type_predicate',
    'type_query',
    'index_type_query',
    'readonly_type',
    'constructor_type',
    'infer_type',
    'conditional_type',
    'lookup_type',
    'nested_type_identifier',
  };
  return extra.contains(type);
}

bool _isFunctionType(String type) {
  const fnTypes = {
    'function_expression',
    'function_declaration',
    'generator_function',
    'generator_function_declaration',
    'arrow_function',
    'method_definition',
  };
  return fnTypes.contains(type);
}

bool _isForStatement(String type) =>
    type == 'for_statement' ||
    type == 'for_in_statement' ||
    type == 'for_of_statement';

final class ExpressionWalker {
  final SrcView view;
  final OnIdentifier onIdentifier;
  final KnownIds knownIds;

  /// 官方 walkIdentifiers 的 rootExp：离开该节点时不摘除其作用域标识符，
  /// 使函数参数（如 slot 解构参数）保留在返回值的 identifiers 中。
  AstNode? rootExp;
  final List<AstNode?> parentStack = [];
  final List<List<String>> _scopeStack = [];

  ExpressionWalker(this.view, this.onIdentifier, this.knownIds);

  void walk(AstNode root) => _visit(root, null);

  void _visit(AstNode node, AstNode? parent) {
    _enter(node, parent);
    final skipped = _isTsTypeSpace(node.type);
    if (!skipped) {
      for (final child in node.children) {
        _visit(child, node);
      }
    }
    _leave(node, parent);
  }

  void _enter(AstNode node, AstNode? parent) {
    if (parent != null) parentStack.add(parent);
    final type = node.type;
    if (type == 'identifier' || type == 'shorthand_property_identifier') {
      _onIdent(node, parent);
    } else if (type == 'undefined') {
      // babel 中 undefined 是 Identifier（true/false/null 则是 Literal，
      // 不进 walker）；官方为其生成子表达式，使注释等尾随文本进入
      // compound 而非滞留 SimpleExpression。
      _onIdent(node, parent);
    } else if (type == 'property_identifier') {
      // 官方 babel 全标识符遍历：成员属性 b（a.b）也生成子表达式以支持
      // sourcemap；但对象字面量/解构模式的静态键按 isStaticPropertyKey 跳过。
      if (!_isStaticPairKey(node, parent)) _onIdent(node, parent);
    } else if (type == 'shorthand_property_identifier_pattern') {
      // 解构模式简写 { a }：对应 babel 简写属性的 value 节点（key!==value）。
      // 赋值解构目标（({ a } = v)）按官方 isInDestructureAssignment 视为
      // 引用并注入 'a: ' 前缀；绑定位置则是局部量。
      _onIdent(node, parent,
          destructureAssignment: _inDestructureAssignment());
    } else if (_isFunctionType(type)) {
      _walkFunctionParams(node);
    } else if (type == 'statement_block') {
      _walkBlockDeclarations(node);
    } else if (type == 'switch_statement') {
      _walkSwitchStatement(node, false);
    } else if (type == 'catch_clause') {
      _walkCatchParam(node);
    } else if (_isForStatement(type)) {
      _walkForStatement(node, false);
    }
  }

  void _leave(AstNode node, AstNode? parent) {
    if (parent != null) parentStack.removeLast();
    if (_isScopeNode(node) && !identical(node, rootExp)) {
      final ids = _scopeStack.isNotEmpty ? _scopeStack.removeLast() : <String>[];
      for (final id in ids) {
        knownIds.unmark(id);
      }
    }
  }

  bool _isScopeNode(AstNode node) =>
      _isFunctionType(node.type) ||
      node.type == 'statement_block' ||
      node.type == 'switch_statement' ||
      node.type == 'catch_clause' ||
      _isForStatement(node.type);

  /// 官方 isStaticPropertyKey：ObjectProperty/ObjectMethod 的非计算键不产生
  /// 子表达式。tree-sitter 对应：pair（字面量键）、pair_pattern（模式键）、
  /// method_definition 首个 property_identifier（方法名简写）。
  bool _isStaticPairKey(AstNode node, AstNode? parent) {
    if (parent == null || parent.children.isEmpty) return false;
    if (parent.type == 'pair' || parent.type == 'pair_pattern') {
      return identical(parent.children.first, node);
    }
    if (parent.type == 'method_definition') {
      return parent.children.isNotEmpty &&
          parent.children.first.type == 'property_identifier' &&
          identical(parent.children.first, node);
    }
    return false;
  }

  /// 官方 isInDestructureAssignment：从当前 parent 起向上穿过模式节点链
  /// （object/array/pair/assignment pattern 等），命中 assignment_expression
  /// 即为赋值解构目标。
  bool _inDestructureAssignment() {
    for (var i = parentStack.length - 1; i >= 0; i--) {
      final p = parentStack[i];
      if (p == null) break;
      if (p.type == 'assignment_expression' ||
          p.type == 'augmented_assignment_expression') {
        return true;
      }
      final t = p.type;
      final patternish = t.endsWith('_pattern') ||
          t == 'object_assignment_pattern' ||
          t == 'pair_pattern';
      if (!patternish) break;
    }
    return false;
  }

  void _onIdent(AstNode node, AstNode? parent,
      {bool destructureAssignment = false}) {
    final name = view.textOf(node);
    // babel Identifier 的 end 包含后缀 typeAnnotation（(e: any) 的参数区间
    // 覆盖 'e: any'），重建时借此剥除参数注解；tree-sitter 中注解是紧邻
    // 兄弟节点，这里对齐区间语义。
    var endByte = node.endByte;
    final siblings = parent?.children;
    if (siblings != null) {
      for (var i = 0; i < siblings.length; i++) {
        if (identical(siblings[i], node)) {
          if (i + 1 < siblings.length &&
              siblings[i + 1].type == 'type_annotation') {
            endByte = siblings[i + 1].endByte;
          }
          break;
        }
      }
    }
    final id = WalkedIdent(
        view.charOf(node.startByte), view.charOf(endByte), name);
    var isRefed = _isReferencedIdentifier(node, parent);
    // 赋值解构目标内的标识符按引用处理（官方 ObjectProperty 分支）。
    if (destructureAssignment && !isRefed) isRefed = true;
    final isLocal = knownIds.contains(name);
    onIdentifier(id, parent, isRefed, isLocal,
        destructureAssignment: destructureAssignment);
  }

  // --- scope declaration walking ---

  void _markScopeIds(List<AstNode> ids) {
    _scopeStack.add(ids.map((n) => view.textOf(n)).toList());
    for (final id in ids) {
      knownIds.mark(view.textOf(id));
    }
  }

  void _walkFunctionParams(AstNode node) {
    final params = <AstNode>[];
    for (final c in node.children) {
      if (c.type == 'formal_parameters') {
        for (final p in c.children) {
          params.addAll(_paramPatterns(p));
        }
      } else if (node.type == 'arrow_function' && c.type == 'identifier') {
        params.add(c);
      }
    }
    final ids = <AstNode>[];
    for (final p in params) {
      ids.addAll(extractIdentifiers(p));
    }
    _markScopeIds(ids);
  }

  List<AstNode> _paramPatterns(AstNode param) {
    if (param.type == 'required_parameter' ||
        param.type == 'optional_parameter') {
      final patterns = <AstNode>[];
      for (final c in param.children) {
        if (_isPattern(c.type)) {
          patterns.add(c);
          // 绑定模式仅一个；其后的子节点是默认值表达式（如 (a = b) 的 b），
          // 属外层引用，不得登记为参数绑定。
          break;
        }
      }
      return patterns;
    }
    return _isPattern(param.type) ? [param] : const [];
  }

  bool _isPattern(String type) {
    const patterns = {
      'identifier',
      'object_pattern',
      'array_pattern',
      'rest_pattern',
      'assignment_pattern',
      'shorthand_property_identifier_pattern',
      'member_expression',
      'subscript_expression',
      'pair_pattern',
    };
    return patterns.contains(type);
  }

  void _walkBlockDeclarations(AstNode block) {
    final ids = <AstNode>[];
    for (final stmt in block.children) {
      _collectDeclarationIds(stmt, ids, null);
    }
    _markScopeIds(ids);
  }

  void _collectDeclarationIds(AstNode stmt, List<AstNode> ids, bool? isVar) {
    switch (stmt.type) {
      case 'lexical_declaration':
      case 'variable_declaration':
        final isVarDecl = stmt.type == 'variable_declaration';
        if (isVar != null && isVarDecl != isVar) return;
        for (final decl in stmt.children) {
          if (decl.type == 'variable_declarator' &&
              decl.children.isNotEmpty) {
            ids.addAll(extractIdentifiers(decl.children.first));
          }
        }
      case 'function_declaration':
      case 'generator_function_declaration':
      case 'class_declaration':
        for (final c in stmt.children) {
          if (c.type == 'identifier') {
            ids.add(c);
            return;
          }
        }
      // 注意：for-in/of 的循环变量属于循环自身作用域（由 _walkForStatement
      // 在进入循环时登记），不得提升进外层块的声明集合。
      case 'for_statement':
        _collectForIds(stmt, ids, isVar ?? true);
      case 'switch_statement':
        _collectSwitchIds(stmt, ids, isVar ?? true);
    }
  }

  void _walkForStatement(AstNode stmt, bool isVar) {
    final ids = <AstNode>[];
    _collectForIds(stmt, ids, isVar);
    _markScopeIds(ids);
  }

  void _collectForIds(AstNode stmt, List<AstNode> ids, bool isVar) {
    for (final c in stmt.children) {
      final isDecl =
          c.type == 'lexical_declaration' || c.type == 'variable_declaration';
      if (!isDecl) continue;
      final isVarDecl = c.type == 'variable_declaration';
      if (isVarDecl != isVar) continue;
      for (final decl in c.children) {
        if (decl.type == 'variable_declarator' && decl.children.isNotEmpty) {
          ids.addAll(extractIdentifiers(decl.children.first));
        }
      }
      return;
    }
    // tree-sitter TS：for-in/of 的 `const x` 是匿名 token，首个具名子节点
    // 即左值模式本身（identifier/pattern），需要登记为循环局部量。
    if (stmt.type == 'for_in_statement' && stmt.children.isNotEmpty) {
      final first = stmt.children.first;
      if (_isPattern(first.type)) ids.addAll(extractIdentifiers(first));
    }
  }

  void _walkSwitchStatement(AstNode stmt, bool isVar) {
    final ids = <AstNode>[];
    _collectSwitchIds(stmt, ids, isVar);
    _markScopeIds(ids);
  }

  void _collectSwitchIds(AstNode stmt, List<AstNode> ids, bool isVar) {
    for (final c in stmt.children) {
      // tree-sitter 层级：switch_statement > switch_body > switch_case。
      if (c.type != 'switch_body') continue;
      for (final cs in c.children) {
        if (cs.type != 'switch_case' && cs.type != 'switch_default') continue;
        for (final stmt2 in cs.children) {
          _collectDeclarationIds(stmt2, ids, isVar);
        }
      }
    }
  }

  void _walkCatchParam(AstNode node) {
    final ids = <AstNode>[];
    for (final c in node.children) {
      if (c.type == 'identifier') {
        ids.add(c);
        break;
      }
      // catch ({ message: { length } }) 等解构参数。
      if (_isPattern(c.type)) {
        ids.addAll(extractIdentifiers(c));
        break;
      }
      if (c.type == 'formal_parameter' && c.children.isNotEmpty) {
        ids.addAll(extractIdentifiers(c.children.first));
        break;
      }
    }
    _markScopeIds(ids);
  }

  /// Port of babel extractIdentifiers.
  List<AstNode> extractIdentifiers(AstNode param) {
    final nodes = <AstNode>[];
    void extract(AstNode p) {
      switch (p.type) {
        case 'identifier':
        case 'shorthand_property_identifier_pattern':
          nodes.add(p);
        case 'member_expression':
        case 'subscript_expression':
          var object = p;
          while (object.type == 'member_expression' ||
              object.type == 'subscript_expression') {
            object = object.children.first;
          }
          nodes.add(object);
        case 'object_pattern':
          for (final prop in p.children) {
            if (prop.type == 'rest_pattern') {
              for (final c in prop.children) {
                extract(c);
              }
            } else if (prop.type == 'pair_pattern') {
              if (prop.children.length > 1) extract(prop.children.last);
            } else if (prop.type == 'shorthand_property_identifier_pattern') {
              extract(prop);
            } else if (prop.type == 'assignment_pattern' ||
                prop.type == 'object_assignment_pattern') {
              extract(prop.children.first);
            }
          }
        case 'array_pattern':
          for (final element in p.children) {
            extract(element);
          }
        case 'rest_pattern':
          for (final c in p.children) {
            extract(c);
          }
        case 'assignment_pattern':
        case 'object_assignment_pattern':
          extract(p.children.first);
      }
    }

    extract(param);
    return nodes;
  }

  // --- isReferenced port ---

  bool _isReferencedIdentifier(AstNode id, AstNode? parent) {
    if (parent == null) return true;
    if (view.textOf(id) == 'arguments') return false;
    final grandparent = parentStack.length >= 2
        ? parentStack[parentStack.length - 2]
        : null;
    if (_isReferenced(id, parent, grandparent)) return true;
    switch (parent.type) {
      case 'assignment_expression':
      case 'augmented_assignment_expression':
      case 'assignment_pattern':
        return true;
      case 'pair':
        return !_pairKeyIs(parent, id) &&
            _isInDestructureAssignment(parent);
      case 'array_pattern':
        return _isInDestructureAssignment(parent);
      // 赋值解构目标里的显式键值 ({ x: y } = v)：y 按引用改写（官方
      // ObjectProperty 分支 key!==id && isInDestructureAssignment）。
      case 'pair_pattern':
        return !_pairKeyIs(parent, id) &&
            _isInDestructureAssignment(parent);
    }
    return false;
  }

  bool _pairKeyIs(AstNode pair, AstNode id) {
    return pair.children.isNotEmpty && identical(pair.children.first, id);
  }

  bool _isInDestructureAssignment(AstNode parent) {
    if (parent.type == 'pair' || parent.type == 'array_pattern') {
      var i = parentStack.length;
      while (i-- > 0) {
        final p = parentStack[i];
        if (p == null) break;
        if (p.type == 'assignment_expression') return true;
        if (p.type != 'pair' &&
            p.type != 'pair_pattern' &&
            !p.type.endsWith('_pattern')) {
          break;
        }
      }
    }
    return false;
  }

  bool _isReferenced(AstNode node, AstNode parent, AstNode? grandparent) {
    switch (parent.type) {
      case 'member_expression':
        return !identical(parent.children.last, node);
      case 'subscript_expression':
        return true;
      case 'variable_declarator':
        return parent.children.length > 1 &&
            identical(parent.children.last, node);
      case 'arrow_function':
        return identical(parent.children.last, node);
      case 'pair':
        if (_pairKeyIs(parent, node)) return false;
        return grandparent == null || grandparent.type != 'object_pattern';
      case 'pair_pattern':
        return false;
      case 'assignment_expression':
      case 'augmented_assignment_expression':
        return parent.children.length > 1 &&
            identical(parent.children.last, node);
      case 'assignment_pattern':
      case 'object_assignment_pattern':
        return parent.children.length > 1 &&
            identical(parent.children.last, node);
      case 'labeled_statement':
      case 'catch_clause':
      case 'rest_pattern':
      case 'break_statement':
      case 'continue_statement':
      case 'function_declaration':
      case 'function_expression':
      case 'generator_function':
      case 'generator_function_declaration':
        return false;
      case 'object_pattern':
      case 'array_pattern':
        return false;
      case 'meta_property':
        return false;
      case 'method_definition':
        return false;
    }
    return true;
  }
}
