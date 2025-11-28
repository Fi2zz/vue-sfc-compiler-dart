import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _SwcParseC =
    Pointer<Utf8> Function(
      Pointer<Utf8> src,
      Pointer<Utf8> language,
      Uint8 keepComments,
    );
typedef _SwcParseDart =
    Pointer<Utf8> Function(
      Pointer<Utf8> src,
      Pointer<Utf8> language,
      int keepComments,
    );
typedef _SwcFreeC = Void Function(Pointer<Utf8> ptr);
typedef _SwcFreeDart = void Function(Pointer<Utf8> ptr);

class SwcFFI {
  final DynamicLibrary _lib;
  _SwcParseDart? _swcParse;
  late final _SwcFreeDart _free;

  SwcFFI._(this._lib) {
    try {
      _swcParse = _lib.lookupFunction<_SwcParseC, _SwcParseDart>('swc_parse');
    } catch (_) {
      _swcParse = null;
    }
    _free = _lib.lookupFunction<_SwcFreeC, _SwcFreeDart>('swc_free');
  }

  static SwcFFI load() {
    final candidates = [
      'lib/native/libswc_ffi.dylib',
      'lib/native/libswc_ffi.so',
      '/opt/homebrew/lib/libswc_ffi.dylib',
      '/usr/local/lib/libswc_ffi.dylib',
    ];
    for (final p in candidates) {
      final f = File(p);
      if (f.existsSync()) {
        return SwcFFI._(DynamicLibrary.open(p));
      }
    }
    throw StateError('SWC FFI library not found. Build with make build-swc.');
  }

  String parse(
    String src, {
    required String language,
    bool keepComments = true,
  }) {
    final inPtr = src.toNativeUtf8();
    final langPtr = language.toNativeUtf8();
    try {
      final result = _swcParse!(inPtr, langPtr, keepComments ? 1 : 0);
      if (result.address == 0) {
        throw StateError('SWC parse returned null');
      }
      try {
        final s = result.toDartString();
        return s;
      } finally {
        _free(result);
      }
    } finally {
      malloc.free(inPtr);
    }
  }
}
