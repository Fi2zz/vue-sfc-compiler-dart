// Compilation context for <script setup>, mirroring the official
// ScriptCompileContext state that affects codegen output.
import '../ts_parser.dart';

import 'script_error.dart';
import 'src_view.dart';
import 'type_infer.dart';

final class ImportBinding {
  final String source;
  final String local;
  final String imported; // 'default' | '*' | named
  final bool typeOnly;
  final bool fromSetup;

  ImportBinding(
    this.source,
    this.local,
    this.imported, {
    required this.typeOnly,
    required this.fromSetup,
  });
}

final class ModelDecl {
  final AstNode? typeNode; // first type argument node
  final String? optionsText; // runtime options with get/set stripped
  final String name;

  ModelDecl(this.name, {this.typeNode, this.optionsText});
}

/// A destructured prop binding: public key -> local name + default node.
final class DestructureBinding {
  final String local;
  final AstNode? defaultNode;

  DestructureBinding(this.local, this.defaultNode);
}

/// Binding type tags; kinds beyond [setupLet] matter for inline-mode
/// template expression rewriting and literal-const hoisting.
enum BindingKind {
  literalConst,
  setupConst,
  setupLet,
  setupMaybeRef,
  setupRef,
  setupReactiveConst,
  props,
}

final class SetupContext {
  final String source; // full SFC source
  final String filename;
  final bool ts;

  String setupSource = ''; // setup block content (untrimmed)
  late SrcView view; // view over setupSource
  Map<String, TypeScopeEntry> typeScope = {};

  int startOffset = 0; // setup content start (char offset in source)
  int endOffset = 0; // setup content end

  final Map<String, ImportBinding> userImports = {};
  final Map<String, BindingKind> scriptBindings = {};
  final Map<String, BindingKind> setupBindings = {};
  final Set<String> helperImports = {};

  bool hasDefinePropsCall = false;
  bool hasDefineEmitCall = false;
  bool hasDefineExposeCall = false;
  bool hasDefineOptionsCall = false;
  bool hasDefineSlotsCall = false;
  bool hasDefineModelCall = false;
  bool hasDefaultExportName = false;
  bool hasDefaultExportRender = false;
  bool hasAwait = false;

  AstNode? propsCall; // defineProps or withDefaults call node
  AstNode? propsRuntimeDecl;
  AstNode? propsTypeDecl;

  /// Official hasVueIgnore on defineProps' type argument: the first member
  /// of a leading intersection/union is skipped during resolution.
  bool propsTypeLeadingIgnored = false;
  AstNode? propsRuntimeDefaults;
  bool propsAssigned = false; // propsDecl != null in official terms
  AstNode? propsDestructureDecl;
  String? propsDestructureRestId;
  final Map<String, DestructureBinding> propsDestructuredBindings = {};
  // 官方在 processDefineProps / genRuntimeProps 中把 props 键登记进
  // bindingMetadata（putIfAbsent 语义）；这里先收集，由 buildBindingMetadata 合并。
  final Set<String> propsKeys = {};

  AstNode? emitsRuntimeDecl;
  AstNode? emitsTypeDecl;
  bool emitAssigned = false; // emitDecl != null

  AstNode? optionsRuntimeDecl;

  final Map<String, ModelDecl> modelDecls = {};

  SetupContext({
    required this.source,
    required this.filename,
    required this.ts,
  });

  String helper(String key) {
    helperImports.add(key);
    return '_$key';
  }

  /// Absolute char offset in the full SFC source for an AST byte offset.
  int abs(int byteOffset) => startOffset + view.charOf(byteOffset);

  Never fail(String reason, AstNode node) {
    throw ScriptCompileError(
      reason: reason,
      filename: filename,
      source: source,
      nodeStart: abs(node.startByte),
      nodeEnd: abs(node.endByte),
    );
  }
}
