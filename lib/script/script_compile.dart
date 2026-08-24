// Orchestrator porting the official compileScript main flow onto
// tree-sitter ASTs + MiniMagic splices over the full SFC source.
import 'package:vue_sfc_parser/sfc_descriptor.dart';
import 'package:vue_sfc_parser/ts_parser.dart';

import 'await_transform.dart';
import 'binding_metadata.dart';
import 'bindings.dart';
import 'destructure_transform.dart';
import 'macro_process.dart';
import 'mini_magic.dart';
import 'node_utils.dart';
import 'runtime_decls.dart';
import 'script_error.dart';
import 'setup_context.dart';
import 'src_view.dart';
import 'type_infer.dart';
import '../template/compile_template.dart';
import '../template/js_nodes.dart' show hUnref;

const normalScriptDefaultVar = '__default__';

final class _Specifier {
  final AstNode node; // identifier / namespace_import / import_specifier
  final String source;
  final String local;
  final String imported; // 'default' | '*' | named
  final bool typeOnly;
  _Specifier(this.node, this.source, this.local, this.imported, this.typeOnly);
}

/// Compile <script setup> into runtime code. Returns the generated code plus
/// the official-style bindingMetadata consumed by compileTemplate.
({String code, Map<String, String> bindings}) compileScriptSetup(
    SfcDescriptor descriptor,
    {bool hoistStatic = false,
    bool inlineTemplate = false}) {
  final source = descriptor.source;
  final filename = descriptor.filename;
  final script = descriptor.script;
  final scriptSetup = descriptor.scriptSetup!;
  final ts = _isTs(script?.lang) || _isTs(scriptSetup.lang);

  if (script != null && script.lang != scriptSetup.lang) {
    throw ScriptCompileError(
      reason: '<script> and <script setup> must have the same language type.',
      filename: filename,
      source: source,
      nodeStart: scriptSetup.locStart,
      nodeEnd: scriptSetup.locStart + 1,
    );
  }

  final startOffset = source.indexOf('>', scriptSetup.locStart) + 1;
  final endOffset = source.lastIndexOf('</', scriptSetup.locEnd);
  final scriptStartOffset =
      script == null ? -1 : source.indexOf('>', script.locStart) + 1;
  final scriptEndOffset =
      script == null ? -1 : source.lastIndexOf('</', script.locEnd);

  final setupSource = source.substring(startOffset, endOffset);
  final lang = ts ? 'ts' : 'js';
  final parser = TSParser();
  final setupRoot = parser.parse(code: setupSource, language: lang);
  AstNode? scriptRoot;
  SrcView? scriptView;
  final typeScope = <String, TypeScopeEntry>{};
  if (script != null) {
    final scriptSource =
        source.substring(scriptStartOffset, scriptEndOffset);
    scriptRoot = parser.parse(code: scriptSource, language: lang);
    scriptView = SrcView(scriptSource);
    // normal <script> type declarations are visible to setup type resolution
    typeScope.addAll(collectTypeScope(scriptRoot, scriptView));
  }

  final view = SrcView(setupSource);
  final ctx = SetupContext(source: source, filename: filename, ts: ts)
    ..setupSource = setupSource
    ..view = view
    ..startOffset = startOffset
    ..endOffset = endOffset
    ..typeScope = typeScope;
  // setup declarations shadow same-named normal-script declarations
  ctx.typeScope.addAll(collectTypeScope(setupRoot, view));
  final s = MiniMagic(source);

  // 1.1 walk import declarations of <script>
  if (scriptRoot != null) {
    for (final node in scriptRoot.children) {
      if (node.type != 'import_statement') continue;
      for (final spec in _importSpecifiers(node, scriptView!)) {
        _registerUserImport(ctx, spec, false);
      }
    }
  }

  // 1.2 walk import declarations of <script setup> (hoist + dedupe)
  for (final node in setupRoot.children) {
    if (node.type != 'import_statement') continue;
    _hoistNode(ctx, s, node.startByte, node.endByte);
    _dedupeImport(ctx, s, node);
  }

  // 1.3 resolve possible user import alias of vue helpers
  final vueImportAliases = <String, String>{};
  for (final entry in ctx.userImports.entries) {
    if (entry.value.source == 'vue') {
      vueImportAliases[entry.value.imported] = entry.value.local;
    }
  }

  // 2.1 process normal <script> body
  AstNode? defaultExport;
  if (scriptRoot != null) {
    defaultExport = _processNormalScript(
      ctx,
      s,
      scriptRoot,
      scriptView!,
      scriptStartOffset,
      scriptEndOffset,
      vueImportAliases,
    );
    if (scriptStartOffset > startOffset) {
      // <script> after <script setup>: move the block up front so that
      // __default__ is declared before the component definition.
      s.appendLeft(scriptEndOffset, '\n');
      s.moveToFront(scriptStartOffset, scriptEndOffset);
    }
  }

  // 2.2 process <script setup> body
  _processSetupBody(ctx, s, setupRoot, vueImportAliases,
      hoistStatic: hoistStatic);

  // 3 props destructure transform
  if (ctx.propsDestructureDecl != null) {
    transformDestructuredProps(ctx, setupRoot, s, vueImportAliases);
  }

  // 5. remove non-script content
  if (script != null) {
    if (startOffset < scriptStartOffset) {
      s.remove(0, startOffset);
      s.remove(endOffset, scriptStartOffset);
      s.remove(scriptEndOffset, source.length);
    } else {
      s.remove(0, scriptStartOffset);
      s.remove(scriptEndOffset, startOffset);
      s.remove(endOffset, source.length);
    }
  } else {
    s.remove(0, startOffset);
    s.remove(endOffset, source.length);
  }

  // 8. finalize setup() argument signature
  var args = '__props';
  if (ctx.propsTypeDecl != null) args += ': any';
  if (ctx.propsAssigned) {
    _rewritePropsDecl(ctx, s);
  }
  if (ctx.hasAwait) {
    final any = ts ? ': any' : '';
    s.prependLeft(startOffset, '\nlet __temp$any, __restore$any\n');
  }
  final destructureElements = <String>[
    // 官方：hasDefineExposeCall || !inlineTemplate 时才解构 expose
    if (ctx.hasDefineExposeCall || !inlineTemplate) 'expose: __expose',
  ];
  if (ctx.emitAssigned) destructureElements.add('emit: __emit');
  if (destructureElements.isNotEmpty) {
    args += ', { ${destructureElements.join(', ')} }';
  }

  // 9. generate return statement
  final propsDecl = genRuntimeProps(ctx);
  if (inlineTemplate && descriptor.template != null) {
    // 官方 inlineTemplate：模板编译为箭头函数，作为 setup 的 return 内联。
    _appendInlineRender(ctx, s, descriptor, endOffset);
  } else {
    final returned = _genReturned(ctx);
    s.appendRight(
      endOffset,
      '\nconst __returned__ = $returned\n'
      "Object.defineProperty(__returned__, '__isScriptSetup', "
      '{ enumerable: false, value: true })\n'
      'return __returned__\n}\n\n',
    );
  }

  // 10. finalize default export
  _assembleHeader(ctx, s, args, propsDecl, defaultExport != null,
      inlineTemplate: inlineTemplate);

  // 11. finalize Vue helper imports
  if (ctx.helperImports.isNotEmpty) {
    final helpers = ctx.helperImports.map((h) => '$h as _$h').join(', ');
    s.prepend("import { $helpers } from 'vue'\n");
  }

  return (code: s.toString(), bindings: buildBindingMetadata(ctx));
}

/// 官方 inlineTemplate 分支：模板以 inline 模式编译为箭头函数，preamble
/// （helper 导入等）前置到模块顶部，render 作为 setup 的返回值内联。
void _appendInlineRender(
  SetupContext ctx,
  MiniMagic s,
  SfcDescriptor descriptor,
  int endOffset,
) {
  final template = descriptor.template!;
  final tpl = compileTemplateSource(
    template.content,
    filename: ctx.filename,
    id: ctx.filename,
    scoped: descriptor.styles.any((st) => st.scoped),
    bindingMetadata: buildBindingMetadata(ctx),
    inline: true,
    isTS: ctx.ts,
  );
  if (tpl.preamble.isNotEmpty) s.prepend(tpl.preamble);
  // 官方：模板 preamble 已提供 unref 时，script 运行时导入里去掉重复项。
  if (tpl.ast.helpers.contains(hUnref)) ctx.helperImports.remove(hUnref);
  s.appendRight(endOffset, '\nreturn ${tpl.code}\n}\n\n');
}

bool _isTs(String? lang) => lang == 'ts' || lang == 'tsx';

void _registerUserImport(SetupContext ctx, _Specifier spec, bool fromSetup) {
  ctx.userImports[spec.local] = ImportBinding(
    spec.source,
    spec.local,
    spec.imported,
    typeOnly: spec.typeOnly,
    fromSetup: fromSetup,
  );
}

// ---------------------------------------------------------------------------
// imports
// ---------------------------------------------------------------------------

String _importSource(AstNode stmt, SrcView view) {
  final str = childOfType(stmt, 'string');
  if (str == null) return '';
  final frag = childOfType(str, 'string_fragment');
  return frag == null ? view.textOf(str) : view.textOf(frag);
}

/// Enumerate import specifiers in babel order: default, namespace, named.
List<_Specifier> _importSpecifiers(AstNode stmt, SrcView view) {
  final out = <_Specifier>[];
  final source = _importSource(stmt, view);
  final clause = childOfType(stmt, 'import_clause');
  final stmtTypeOnly = _statementIsTypeImport(stmt, clause, view);
  if (clause == null) return out;
  for (final c in clause.children) {
    if (c.type == 'identifier') {
      out.add(_Specifier(c, source, view.textOf(c), 'default', stmtTypeOnly));
    } else if (c.type == 'namespace_import') {
      final id = childOfType(c, 'identifier');
      if (id != null) {
        out.add(_Specifier(c, source, view.textOf(id), '*', stmtTypeOnly));
      }
    } else if (c.type == 'named_imports') {
      for (final spec in childrenOfType(c, 'import_specifier')) {
        out.add(_namedSpecifier(spec, source, stmtTypeOnly, view));
      }
    }
  }
  return out;
}

bool _statementIsTypeImport(AstNode stmt, AstNode? clause, SrcView view) {
  final end = clause?.startByte ?? stmt.endByte;
  return view.slice(stmt.startByte + 6, end).trim() == 'type';
}

_Specifier _namedSpecifier(
  AstNode spec,
  String source,
  bool stmtTypeOnly,
  SrcView view,
) {
  final ids = childrenOfType(spec, 'identifier');
  final imported = view.textOf(ids.first);
  final local = ids.length > 1 ? view.textOf(ids[1]) : imported;
  final specTypeOnly =
      view.slice(spec.startByte, ids.first.startByte).trim() == 'type';
  return _Specifier(spec, source, local, imported, stmtTypeOnly || specTypeOnly);
}

/// Port of the setup-import dedupe pass (official step 1.2).
void _dedupeImport(SetupContext ctx, MiniMagic s, AstNode node) {
  final specifiers = _importSpecifiers(node, ctx.view);
  var removed = 0;
  void removeSpecifier(int i) {
    final removeLeft = i > removed;
    removed++;
    final current = specifiers[i].node;
    final next = i + 1 < specifiers.length ? specifiers[i + 1].node : null;
    final from = removeLeft
        ? ctx.abs(specifiers[i - 1].node.endByte)
        : ctx.abs(current.startByte);
    final to = next != null && !removeLeft
        ? ctx.abs(next.startByte)
        : ctx.abs(current.endByte);
    s.remove(from, to);
  }

  for (var i = 0; i < specifiers.length; i++) {
    final spec = specifiers[i];
    final existing = ctx.userImports[spec.local];
    if (spec.source == 'vue' && macros.contains(spec.imported)) {
      if (spec.local != spec.imported) {
        ctx.fail(
          '`${spec.imported}` is a compiler macro and cannot be aliased to '
          'a different name.',
          spec.node,
        );
      }
      removeSpecifier(i);
    } else if (existing != null) {
      if (existing.source == spec.source &&
          existing.imported == spec.imported) {
        removeSpecifier(i);
      } else {
        ctx.fail('different imports aliased to same local name.', spec.node);
      }
    } else {
      _registerUserImport(ctx, spec, true);
    }
  }
  if (specifiers.isNotEmpty && removed == specifiers.length) {
    s.remove(ctx.abs(node.startByte), ctx.abs(node.endByte));
  }
}

/// Port of hoistNode: move [startByte, endByte) to the front of the output.
/// Babel attaches comments following a statement (even across blank lines)
/// as its trailingComments, so the moved range extends over all following
/// comments and then over trailing whitespace.
void _hoistNode(SetupContext ctx, MiniMagic s, int startByte, int endByte) {
  final start = ctx.abs(startByte);
  var end = ctx.abs(endByte);
  final source = ctx.source;
  while (true) {
    var i = end;
    while (i < source.length && _isWhitespace(source.codeUnitAt(i))) {
      i++;
    }
    if (i + 1 < source.length && source.codeUnitAt(i) == 0x2F) {
      if (source.codeUnitAt(i + 1) == 0x2F) {
        final nl = source.indexOf('\n', i);
        end = nl == -1 ? source.length : nl;
        continue;
      } else if (source.codeUnitAt(i + 1) == 0x2A) {
        final close = source.indexOf('*/', i + 2);
        if (close != -1) {
          end = close + 2;
          continue;
        }
      }
    }
    break;
  }
  while (end < source.length && _isWhitespace(source.codeUnitAt(end))) {
    end++;
  }
  s.moveToFront(start, end);
}

bool _isWhitespace(int cu) =>
    cu == 0x20 || cu == 0x09 || cu == 0x0A || cu == 0x0D || cu == 0x0B || cu == 0x0C;

// ---------------------------------------------------------------------------
// normal <script>
// ---------------------------------------------------------------------------

AstNode? _processNormalScript(
  SetupContext ctx,
  MiniMagic s,
  AstNode root,
  SrcView view,
  int scriptStartOffset,
  int scriptEndOffset,
  Map<String, String> vueImportAliases,
) {
  AstNode? defaultExport;
  int abs(int byteOffset) => scriptStartOffset + view.charOf(byteOffset);
  for (final node in root.children) {
    if (node.type == 'export_statement') {
      final decl = node.children.isEmpty ? null : node.children.first;
      final head = decl == null
          ? ''
          : view.slice(node.startByte + 6, decl.startByte);
      if (head.contains('default')) {
        defaultExport = node;
        _checkDefaultExportOptions(ctx, decl, view);
        s.overwrite(
          abs(node.startByte),
          abs(decl!.startByte),
          'const $normalScriptDefaultVar = ',
        );
      } else if (decl != null && decl.type == 'export_clause') {
        _processExportDefaultSpecifier(ctx, s, node, decl, view, abs,
            scriptEndOffset);
      }
      if (decl != null && _isDeclarable(decl)) {
        // 官方 from === 'script'：静态 const 一律登记 literal-const。
        walkDeclaration(ctx, decl, ctx.scriptBindings,
            vueImportAliases: vueImportAliases,
            fromScript: true,
            view: view);
      }
    } else if (_isDeclarable(node)) {
      walkDeclaration(ctx, node, ctx.scriptBindings,
          vueImportAliases: vueImportAliases,
          fromScript: true,
          view: view);
    }
  }
  return defaultExport;
}

bool _isDeclarable(AstNode node) {
  return node.type == 'lexical_declaration' ||
      node.type == 'variable_declaration' ||
      node.type == 'function_declaration' ||
      node.type == 'generator_function_declaration' ||
      node.type == 'class_declaration' ||
      node.type == 'abstract_class_declaration' ||
      node.type == 'enum_declaration';
}

void _checkDefaultExportOptions(
  SetupContext ctx,
  AstNode? declaration,
  SrcView view,
) {
  AstNode? options;
  if (declaration != null && declaration.type == 'object') {
    options = declaration;
  } else if (declaration != null && declaration.type == 'call_expression') {
    final args = childOfType(declaration, 'arguments');
    if (args != null &&
        args.children.isNotEmpty &&
        args.children.first.type == 'object') {
      options = args.children.first;
    }
  }
  if (options == null) return;
  for (final p in objectProperties(options)) {
    final key = _propertyKey(p, view);
    if (key == 'name') ctx.hasDefaultExportName = true;
    if (key == 'render') ctx.hasDefaultExportRender = true;
  }
}

String? _propertyKey(AstNode prop, SrcView view) {
  if (prop.type != 'pair' && prop.type != 'method_definition') return null;
  final key = childOfType(prop, 'property_identifier');
  return key == null ? null : view.textOf(key);
}

void _processExportDefaultSpecifier(
  SetupContext ctx,
  MiniMagic s,
  AstNode node,
  AstNode clause,
  SrcView view,
  int Function(int) abs,
  int scriptEndOffset,
) {
  final specifiers = childrenOfType(clause, 'export_specifier');
  AstNode? defaultSpec;
  for (final spec in specifiers) {
    final ids = childrenOfType(spec, 'identifier');
    if (ids.length > 1 && view.textOf(ids[1]) == 'default') {
      defaultSpec = spec;
      break;
    }
  }
  if (defaultSpec == null) return;
  final local =
      view.textOf(childrenOfType(defaultSpec, 'identifier').first);
  if (specifiers.length > 1) {
    s.remove(abs(defaultSpec.startByte), abs(defaultSpec.endByte));
  } else {
    s.remove(abs(node.startByte), abs(node.endByte));
  }
  final sourceNode = childOfType(node, 'string');
  if (sourceNode != null) {
    final frag = childOfType(sourceNode, 'string_fragment');
    final src = frag == null ? view.textOf(sourceNode) : view.textOf(frag);
    s.prepend(
      "import { $local as $normalScriptDefaultVar } from '$src'\n",
    );
  } else {
    s.appendLeft(
      scriptEndOffset,
      '\nconst $normalScriptDefaultVar = $local\n',
    );
  }
}

// ---------------------------------------------------------------------------
// <script setup> body
// ---------------------------------------------------------------------------

void _processSetupBody(
  SetupContext ctx,
  MiniMagic s,
  AstNode root,
  Map<String, String> vueImportAliases, {
  bool hoistStatic = false,
}) {
  for (final node in root.children) {
    if (node.type == 'expression_statement' && node.children.isNotEmpty) {
      final expr = unwrapTSNode(node.children.first);
      final consumed = processDefineProps(ctx, expr) ||
          processDefineEmits(ctx, expr) ||
          processDefineOptions(ctx, expr) ||
          processDefineSlots(ctx, expr, s);
      if (consumed) {
        s.remove(ctx.abs(node.startByte), ctx.abs(node.endByte));
      } else if (!processDefineExpose(ctx, expr, s)) {
        processDefineModel(ctx, expr, s);
      }
    }

    if (node.type == 'lexical_declaration' ||
        node.type == 'variable_declaration') {
      _processVarDeclMacros(ctx, s, node);
    }

    // 官方：walkDeclaration 返回 isAllLiteral，hoistStatic 时整条语句提升。
    var allLiteral = false;
    if (node.type == 'lexical_declaration' ||
        node.type == 'variable_declaration') {
      allLiteral = walkDeclaration(
        ctx,
        node,
        ctx.setupBindings,
        vueImportAliases: vueImportAliases,
        hoistStatic: hoistStatic,
        propsDestructureEnabled: ctx.propsDestructureDecl != null,
      );
    } else if (node.type == 'function_declaration' ||
        node.type == 'generator_function_declaration' ||
        node.type == 'class_declaration' ||
        node.type == 'abstract_class_declaration' ||
        node.type == 'enum_declaration') {
      allLiteral = walkDeclaration(
        ctx,
        node,
        ctx.setupBindings,
        vueImportAliases: vueImportAliases,
        hoistStatic: hoistStatic,
      );
    }
    if (hoistStatic && allLiteral) {
      _hoistNode(ctx, s, node.startByte, node.endByte);
    }

    // top-level await
    if (node.type == 'lexical_declaration' ||
        node.type == 'variable_declaration' ||
        (node.type.endsWith('_statement') &&
            node.type != 'export_statement' &&
            node.type != 'import_statement')) {
      walkForAwait(ctx, node, s, root.children);
    }

    // ES module exports are not allowed (type exports are hoisted below)
    if (node.type == 'export_statement' && !_isTypeExport(ctx, node)) {
      ctx.fail(
        '<script setup> cannot contain ES module exports. '
        'If you are using a previous version of <script setup>, please '
        'consult the updated RFC at https://github.com/vuejs/rfcs/pull/227.',
        node,
      );
    }

    if (ctx.ts && _hoistableTypeDecl(node)) {
      _hoistNode(ctx, s, node.startByte, node.endByte);
    }
  }
}

bool _isTypeExport(SetupContext ctx, AstNode node) {
  if (node.type != 'export_statement') return false;
  final decl = node.children.isEmpty ? null : node.children.first;
  if (decl != null &&
      (decl.type == 'interface_declaration' ||
          decl.type == 'type_alias_declaration')) {
    return true;
  }
  final end = decl?.startByte ?? node.endByte;
  return ctx.view.slice(node.startByte + 6, end).trim() == 'type';
}

bool _hoistableTypeDecl(AstNode node) {
  switch (node.type) {
    case 'type_alias_declaration':
    case 'interface_declaration':
    case 'ambient_declaration':
    case 'internal_module':
    case 'module':
      return true;
    case 'export_statement':
      return true; // caller guarantees _isTypeExport
    default:
      return false;
  }
}

void _processVarDeclMacros(SetupContext ctx, MiniMagic s, AstNode node) {
  final decls = childrenOfType(node, 'variable_declarator');
  final total = decls.length;
  var left = total;
  int? lastNonRemoved;
  for (var i = 0; i < total; i++) {
    final decl = decls[i];
    final id = decl.children.first;
    final init = _declInitNode(decl);
    if (init == null) {
      lastNonRemoved = i;
      continue;
    }
    if (processDefineOptions(ctx, init)) {
      ctx.fail(
        'defineOptions() has no returning value, it cannot be assigned.',
        node,
      );
    }
    final isDefineProps = processDefineProps(ctx, init, declId: id);
    if (ctx.propsDestructureRestId != null) {
      ctx.setupBindings[ctx.propsDestructureRestId!] = BindingKind.setupConst;
    }
    final isDefineEmits =
        !isDefineProps && processDefineEmits(ctx, init, declId: id);
    if (!isDefineEmits) {
      processDefineSlots(ctx, init, s, declId: id) ||
          processDefineModel(ctx, init, s);
    }
    if (isDefineProps &&
        ctx.propsDestructureRestId == null &&
        ctx.propsDestructureDecl != null) {
      if (left == 1) {
        s.remove(ctx.abs(node.startByte), ctx.abs(node.endByte));
      } else {
        var start = ctx.abs(decl.startByte);
        var end = ctx.abs(decl.endByte);
        if (i == total - 1) {
          start = ctx.abs(decls[lastNonRemoved!].endByte);
        } else {
          end = ctx.abs(decls[i + 1].startByte);
        }
        s.remove(start, end);
        left--;
      }
    } else if (isDefineEmits) {
      s.overwrite(ctx.abs(init.startByte), ctx.abs(init.endByte), '__emit');
    } else {
      lastNonRemoved = i;
    }
  }
}

AstNode? _declInitNode(AstNode declarator) {
  if (declarator.children.length < 2) return null;
  final last = declarator.children.last;
  if (last.type == 'type_annotation') return null;
  return unwrapTSNode(last);
}

// ---------------------------------------------------------------------------
// props decl rewrite + returned + header assembly
// ---------------------------------------------------------------------------

void _rewritePropsDecl(SetupContext ctx, MiniMagic s) {
  if (ctx.propsDestructureRestId != null) {
    final keys = ctx.propsDestructuredBindings.keys.toList();
    s.overwrite(
      ctx.abs(ctx.propsCall!.startByte),
      ctx.abs(ctx.propsCall!.endByte),
      '${ctx.helper('createPropsRestProxy')}(__props, '
      '[${keys.map(jsonString).join(',')}])',
    );
    s.overwrite(
      ctx.abs(ctx.propsDestructureDecl!.startByte),
      ctx.abs(ctx.propsDestructureDecl!.endByte),
      ctx.propsDestructureRestId!,
    );
  } else if (ctx.propsDestructureDecl == null) {
    s.overwrite(
      ctx.abs(ctx.propsCall!.startByte),
      ctx.abs(ctx.propsCall!.endByte),
      '__props',
    );
  }
}

String _genReturned(SetupContext ctx) {
  final allBindings = <String, BindingKind?>{};
  for (final entry in ctx.scriptBindings.entries) {
    allBindings[entry.key] = entry.value;
  }
  for (final entry in ctx.setupBindings.entries) {
    allBindings[entry.key] = entry.value;
  }
  final importKeys = <String>{};
  for (final entry in ctx.userImports.entries) {
    if (entry.value.typeOnly) continue;
    allBindings[entry.key] = null; // null marks an import binding
    importKeys.add(entry.key);
  }
  final buf = StringBuffer('{ ');
  for (final key in allBindings.keys) {
    final kind = allBindings[key];
    if (importKeys.contains(key)) {
      final imp = ctx.userImports[key]!;
      if (imp.source != 'vue' && !imp.source.endsWith('.vue')) {
        buf.write('get $key() { return $key }, ');
      } else {
        buf.write('$key, ');
      }
    } else if (kind == BindingKind.setupLet) {
      final setArg = key == 'v' ? '_v' : 'v';
      buf.write(
        'get $key() { return $key }, set $key($setArg) { $key = $setArg }, ',
      );
    } else {
      buf.write('$key, ');
    }
  }
  var out = buf.toString();
  if (out.endsWith(', ')) out = out.substring(0, out.length - 2);
  return '$out }';
}

void _assembleHeader(
  SetupContext ctx,
  MiniMagic s,
  String args,
  String? propsDecl,
  bool hasDefaultExport, {
  bool inlineTemplate = false,
}) {
  var runtimeOptions = '';
  final match = RegExp(r'([^/\\]+)\.\w+$').firstMatch(ctx.filename);
  if (!ctx.hasDefaultExportName &&
      ctx.filename.isNotEmpty &&
      ctx.filename != 'anonymous.vue' &&
      match != null) {
    runtimeOptions += "\n  __name: '${match[1]}',";
  }
  if (propsDecl != null) runtimeOptions += '\n  props: $propsDecl,';
  final emitsDecl = genRuntimeEmits(ctx);
  if (emitsDecl != null) runtimeOptions += '\n  emits: $emitsDecl,';

  var definedOptions = '';
  if (ctx.optionsRuntimeDecl != null) {
    definedOptions = ctx.view.textOf(ctx.optionsRuntimeDecl!).trim();
  }
  final exposeCall =
      ctx.hasDefineExposeCall || inlineTemplate ? '' : '  __expose();\n';
  final async = ctx.hasAwait ? 'async ' : '';

  if (ctx.ts) {
    final def = (hasDefaultExport ? '\n  ...$normalScriptDefaultVar,' : '') +
        (definedOptions.isNotEmpty ? '\n  ...$definedOptions,' : '');
    s.prependLeft(
      ctx.startOffset,
      '\nexport default /*@__PURE__*/${ctx.helper('defineComponent')}'
      '({$def$runtimeOptions\n  $async'
      'setup($args) {\n$exposeCall',
    );
    s.appendRight(ctx.endOffset, '})');
  } else if (hasDefaultExport || definedOptions.isNotEmpty) {
    s.prependLeft(
      ctx.startOffset,
      '\nexport default /*@__PURE__*/Object.assign('
      '${hasDefaultExport ? '$normalScriptDefaultVar, ' : ''}'
      '${definedOptions.isNotEmpty ? '$definedOptions, ' : ''}'
      '{$runtimeOptions\n  $async'
      'setup($args) {\n$exposeCall',
    );
    s.appendRight(ctx.endOffset, '})');
  } else {
    s.prependLeft(
      ctx.startOffset,
      '\nexport default {$runtimeOptions\n  $async'
      'setup($args) {\n$exposeCall',
    );
    s.appendRight(ctx.endOffset, '}');
  }
}
