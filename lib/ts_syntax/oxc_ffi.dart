// English comments per ~/REPO rule.
// dart:ffi bindings for the oxc parser cdylib (liboxc_ts).

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _oxc_parse_native =
    Pointer<Utf8> Function(Pointer<Utf8>, Uint32, Uint32);
typedef _oxc_batch_native =
    Pointer<Utf8> Function(Pointer<Pointer<Utf8>>, Uint32, Uint32);
typedef _oxc_free_native = Void Function(Pointer<Utf8>);

/// Raised when the worker reports a syntax error in the input.
class OxcParseException implements Exception {
  final String message;
  final int start;
  final int end;
  const OxcParseException(this.message, this.start, this.end);

  @override
  String toString() => 'OxcParseException($start..$end): $message';
}

/// FFI handle for liboxc_ts. Two symbols only: oxc_parse / oxc_free.
class OxcFFI {
  final DynamicLibrary _lib;
  late final Pointer<Utf8> Function(Pointer<Utf8>, int, int) _parse;
  late final Pointer<Utf8> Function(Pointer<Pointer<Utf8>>, int, int) _batch;
  late final void Function(Pointer<Utf8>) _free;

  OxcFFI._(this._lib) {
    _parse = _lib
        .lookupFunction<
          _oxc_parse_native,
          Pointer<Utf8> Function(Pointer<Utf8>, int, int)
        >('oxc_parse');
    _batch = _lib
        .lookupFunction<
          _oxc_batch_native,
          Pointer<Utf8> Function(Pointer<Pointer<Utf8>>, int, int)
        >('oxc_parse_batch');
    _free = _lib.lookupFunction<_oxc_free_native, void Function(Pointer<Utf8>)>(
      'oxc_free',
    );
  }

  /// Language tags mirror the worker's FFI contract.
  static int langTag(String language) {
    switch (language) {
      case 'tsx':
        return 1;
      case 'js':
        return 2;
      case 'jsx':
        return 3;
      default:
        return 0; // ts
    }
  }

  /// Parse [code] and return the decoded JSON payload.
  /// Throws [OxcParseException] on worker-reported syntax errors.
  Map<String, dynamic> parseJson(String code, String language) {
    final src = code.toNativeUtf8();
    final out = _parse(src, src.length, langTag(language));
    malloc.free(src);
    if (out == nullptr) {
      throw StateError('oxc_parse returned null');
    }
    try {
      return _decode(out);
    } finally {
      _free(out);
    }
  }

  /// Parse [sources] in one round-trip; returns one payload map per entry,
  /// each shaped exactly like [parseJson] output (per-item error isolation
  /// is preserved by the worker).
  List<Map<String, dynamic>> parseJsonBatch(
    List<String> sources,
    String language,
  ) {
    if (sources.isEmpty) return const [];
    final count = sources.length;
    final stride = sizeOf<Pointer<Utf8>>();
    final array = malloc.allocate<Pointer<Utf8>>(stride * count);
    final natives = <Pointer<Utf8>>[];
    try {
      for (var i = 0; i < count; i++) {
        final p = sources[i].toNativeUtf8();
        natives.add(p);
        array[i] = p;
      }
      final out = _batch(array, count, langTag(language));
      if (out == nullptr) {
        throw StateError('oxc_parse_batch returned null');
      }
      final List<dynamic> items;
      try {
        items =
            (jsonDecode(out.toDartString()) as Map<String, dynamic>)['items']
                as List<dynamic>;
      } finally {
        _free(out);
      }
      return [for (final item in items) item as Map<String, dynamic>];
    } finally {
      for (final p in natives) {
        malloc.free(p);
      }
      malloc.free(array);
    }
  }

  Map<String, dynamic> _decode(Pointer<Utf8> out) {
    final payload = jsonDecode(out.toDartString()) as Map<String, dynamic>;
    if (payload['ok'] == true) return payload;
    final diagnostic = payload['diagnostic'] as Map<String, dynamic>?;
    throw OxcParseException(
      diagnostic?['error'] as String? ??
          payload['error'] as String? ??
          'parse failed',
      diagnostic?['start'] as int? ?? 0,
      diagnostic?['end'] as int? ?? 0,
    );
  }

  /// Load liboxc_ts from lib/native first, then the cargo build output.
  /// The handle is process-global; cache it (call sites construct TSParser
  /// per parse).
  static OxcFFI load() => _cached ??= _loadUncached();
  static OxcFFI? _cached;

  static OxcFFI _loadUncached() {
    final lib = _openFirst(_candidates());
    if (lib == null) {
      throw StateError('liboxc_ts not found. Build with: make build-worker');
    }
    return OxcFFI._(lib);
  }

  /// Platform-native extension first, same convention as the tree-sitter libs.
  static List<String> _candidates() {
    final dylib = Platform.isMacOS
        ? 'lib/native/liboxc_ts.dylib'
        : 'lib/native/liboxc_ts.so';
    return [
      dylib,
      'lib/native/liboxc_ts.so',
      'lib/native/liboxc_ts.dylib',
      'worker/oxc_ts/target/release/liboxc_ts.dylib',
    ];
  }

  /// Open the first candidate that exists and loads; skip broken binaries.
  static DynamicLibrary? _openFirst(List<String> candidates) {
    for (final path in candidates) {
      if (!File(path).existsSync()) continue;
      try {
        return DynamicLibrary.open(path);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
