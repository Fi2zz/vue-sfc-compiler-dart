// English comments per ~/REPO rule.
// Tree-sitter core FFI bindings and language loaders for TypeScript/TSX.
// This file exposes the minimal C API needed to parse code and traverse AST.

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Opaque types mapping to Tree-sitter C structs.
final class TSParser extends Opaque {}

final class TSLanguage extends Opaque {}

final class TSTree extends Opaque {}

/// Struct mapping of TSPoint { uint32_t row; uint32_t column; }
final class TSPoint extends Struct {
  @Uint32()
  external int row;

  @Uint32()
  external int column;
}

/// Struct mapping of TSNode as defined in api.h.
/// typedef struct TSNode { uint32_t context[4]; const void *id; const TSTree *tree; } TSNode;
final class TSNode extends Struct {
  @Uint32()
  external int context0;
  @Uint32()
  external int context1;
  @Uint32()
  external int context2;
  @Uint32()
  external int context3;

  external Pointer<Void> id;
  external Pointer<TSTree> tree;
}

/// Function typedefs for the subset of the C API we use.
typedef _ts_parser_new = Pointer<TSParser> Function();
typedef _ts_parser_delete = Void Function(Pointer<TSParser>);
typedef _ts_parser_set_language =
    Uint8 Function(Pointer<TSParser>, Pointer<TSLanguage>);
typedef _ts_parser_parse_string =
    Pointer<TSTree> Function(
      Pointer<TSParser>,
      Pointer<TSTree>,
      Pointer<Utf8>,
      Uint32,
    );

typedef _ts_tree_delete = Void Function(Pointer<TSTree>);
typedef _ts_tree_root_node = TSNode Function(Pointer<TSTree>);

typedef _ts_node_type = Pointer<Utf8> Function(TSNode);
typedef _ts_node_child_count = Uint32 Function(TSNode);
typedef _ts_node_child = TSNode Function(TSNode, Uint32);
typedef _ts_node_named_child_count = Uint32 Function(TSNode);
typedef _ts_node_named_child = TSNode Function(TSNode, Uint32);
typedef _ts_node_start_point = TSPoint Function(TSNode);
typedef _ts_node_end_point = TSPoint Function(TSNode);
typedef _ts_node_start_byte = Uint32 Function(TSNode);
typedef _ts_node_end_byte = Uint32 Function(TSNode);

/// Language symbol signatures: exported by grammar libraries.
typedef _ts_language_fn = Pointer<TSLanguage> Function();

/// Core Tree-sitter FFI. Handles dynamic library loading and symbol lookups.
class TSFFI {
  final DynamicLibrary core;

  // Core functions
  late final Pointer<TSParser> Function() tsParserNew;
  late final void Function(Pointer<TSParser>) tsParserDelete;
  late final bool Function(Pointer<TSParser>, Pointer<TSLanguage>)
  tsParserSetLanguage;
  late final Pointer<TSTree> Function(
    Pointer<TSParser>,
    Pointer<TSTree>,
    Pointer<Utf8>,
    int,
  )
  tsParserParseString;

  late final void Function(Pointer<TSTree>) tsTreeDelete;
  late final TSNode Function(Pointer<TSTree>) tsTreeRootNode;

  late final Pointer<Utf8> Function(TSNode) tsNodeType;
  late final int Function(TSNode) tsNodeChildCount;
  late final TSNode Function(TSNode, int) tsNodeChild;
  late final int Function(TSNode) tsNodeNamedChildCount;
  late final TSNode Function(TSNode, int) tsNodeNamedChild;
  late final TSPoint Function(TSNode) tsNodeStartPoint;
  late final TSPoint Function(TSNode) tsNodeEndPoint;
  late final int Function(TSNode) tsNodeStartByte;
  late final int Function(TSNode) tsNodeEndByte;

  TSFFI._(this.core) {
    // Resolve core symbols.
    tsParserNew = core
        .lookupFunction<_ts_parser_new, Pointer<TSParser> Function()>(
          'ts_parser_new',
        );
    tsParserDelete = core
        .lookupFunction<_ts_parser_delete, void Function(Pointer<TSParser>)>(
          'ts_parser_delete',
        );
    final setLangNative = core
        .lookupFunction<
          _ts_parser_set_language,
          int Function(Pointer<TSParser>, Pointer<TSLanguage>)
        >('ts_parser_set_language');
    tsParserSetLanguage = (parser, lang) => setLangNative(parser, lang) != 0;
    tsParserParseString = core
        .lookupFunction<
          _ts_parser_parse_string,
          Pointer<TSTree> Function(
            Pointer<TSParser>,
            Pointer<TSTree>,
            Pointer<Utf8>,
            int,
          )
        >('ts_parser_parse_string');

    tsTreeDelete = core
        .lookupFunction<_ts_tree_delete, void Function(Pointer<TSTree>)>(
          'ts_tree_delete',
        );
    tsTreeRootNode = core
        .lookupFunction<_ts_tree_root_node, TSNode Function(Pointer<TSTree>)>(
          'ts_tree_root_node',
        );

    tsNodeType = core
        .lookupFunction<_ts_node_type, Pointer<Utf8> Function(TSNode)>(
          'ts_node_type',
        );
    tsNodeChildCount = core
        .lookupFunction<_ts_node_child_count, int Function(TSNode)>(
          'ts_node_child_count',
        );
    tsNodeChild = core
        .lookupFunction<_ts_node_child, TSNode Function(TSNode, int)>(
          'ts_node_child',
        );
    tsNodeNamedChildCount = core
        .lookupFunction<_ts_node_named_child_count, int Function(TSNode)>(
          'ts_node_named_child_count',
        );
    tsNodeNamedChild = core
        .lookupFunction<_ts_node_named_child, TSNode Function(TSNode, int)>(
          'ts_node_named_child',
        );
    tsNodeStartPoint = core
        .lookupFunction<_ts_node_start_point, TSPoint Function(TSNode)>(
          'ts_node_start_point',
        );
    tsNodeEndPoint = core
        .lookupFunction<_ts_node_end_point, TSPoint Function(TSNode)>(
          'ts_node_end_point',
        );
    tsNodeStartByte = core
        .lookupFunction<_ts_node_start_byte, int Function(TSNode)>(
          'ts_node_start_byte',
        );
    tsNodeEndByte = core
        .lookupFunction<_ts_node_end_byte, int Function(TSNode)>(
          'ts_node_end_byte',
        );
  }

  /// Create a new instance by loading the core dynamic library from lib/native.
  /// Tries .dylib first on macOS, then .so as a fallback.
  static TSFFI loadCore() {
    final candidates = <String>[
      'lib/native/libtree-sitter.dylib',
      'lib/native/libtree-sitter.so',
      // Homebrew default paths on macOS (Apple Silicon / Intel)
      '/opt/homebrew/lib/libtree-sitter.dylib',
      '/usr/local/lib/libtree-sitter.dylib',
    ];
    DynamicLibrary? lib;
    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) {
        lib = DynamicLibrary.open(path);
        break;
      }
    }
    if (lib == null) {
      throw StateError(
        'Tree-sitter core library not found in lib/native. Build with make build-core.',
      );
    }
    return TSFFI._(lib);
  }

  /// Load a grammar library and return the exported TSLanguage pointer.
  /// [symbolName] should be like 'tree_sitter_typescript' or 'tree_sitter_tsx'.
  static Pointer<TSLanguage> loadLanguageSymbol({
    required String libPath,
    required String symbolName,
  }) {
    final file = File(libPath);
    if (!file.existsSync()) {
      throw StateError('Grammar library missing: $libPath');
    }
    final dylib = DynamicLibrary.open(libPath);
    final fn = dylib
        .lookupFunction<_ts_language_fn, Pointer<TSLanguage> Function()>(
          symbolName,
        );
    return fn();
  }

  /// Convenience to load the TypeScript grammar.
  static Pointer<TSLanguage> loadTypescriptLanguage() {
    // Try .dylib then .so
    final candidates = [
      'lib/native/tree-sitter-typescript.dylib',
      'lib/native/tree-sitter-typescript.so',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) {
        return loadLanguageSymbol(
          libPath: p,
          symbolName: 'tree_sitter_typescript',
        );
      }
    }
    throw StateError(
      'TypeScript grammar library not found. Build with make build-ts.',
    );
  }

  static Pointer<TSLanguage> load(String language) {
    switch (language) {
      case 'ts':
        return loadTypescriptLanguage();
      case 'tsx':
        return loadTsxLanguage();
      case 'js':
        return loadJavaScriptLanguage();
      default:
        throw StateError('Unknown language: $language');
    }
  }

  /// Convenience to load the TSX grammar.
  static Pointer<TSLanguage> loadTsxLanguage() {
    final candidates = [
      'lib/native/tree-sitter-tsx.dylib',
      'lib/native/tree-sitter-tsx.so',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) {
        return loadLanguageSymbol(libPath: p, symbolName: 'tree_sitter_tsx');
      }
    }
    throw StateError(
      'TSX grammar library not found. Build with make build-ts.',
    );
  }

  /// Convenience to load the JavaScript grammar.
  static Pointer<TSLanguage> loadJavaScriptLanguage() {
    final candidates = [
      'lib/native/tree-sitter-javascript.dylib',
      'lib/native/tree-sitter-javascript.so',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) {
        return loadLanguageSymbol(
          libPath: p,
          symbolName: 'tree_sitter_javascript',
        );
      }
    }
    throw StateError(
      'JavaScript grammar library not found. Build with make build-js.',
    );
  }
}
