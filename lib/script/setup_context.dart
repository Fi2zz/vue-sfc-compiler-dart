// Compilation context for <script setup>, mirroring the official
// ScriptCompileContext state that affects codegen output.
import 'package:vue_sfc_parser/ts_parser.dart';

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

/// Binding type tags; only [setupLet] changes codegen shape.
enum BindingKind { literalConst, setupConst, setupLet, setupMaybeRef, props }

final class SetupContext {
  final String source; // full SFC source
  final String filename;
  final bool ts;

  String setupSource = ''; // setup block content
  Map<String, AstNode> typeScope = {};

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
  bool hasDefaultExportName = false;
  bool hasDefaultExportRender = false;

  AstNode? propsCall; // defineProps or withDefaults call node
  AstNode? propsRuntimeDecl;
  AstNode? propsTypeDecl;
  AstNode? propsRuntimeDefaults;
  bool propsDestructure = false;
  final Map<String, String?> destructuredDefaults = {};

  AstNode? emitsRuntimeDecl;
  AstNode? emitsTypeDecl;
  bool emitAssigned = false;

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
}
