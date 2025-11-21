import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _SwcParseTsC =
    Pointer<Utf8> Function(Pointer<Utf8> src, Uint8 isTsx, Uint8 keepComments);
typedef _SwcParseTsDart =
    Pointer<Utf8> Function(Pointer<Utf8> src, int isTsx, int keepComments);
typedef _SwcFreeC = Void Function(Pointer<Utf8> ptr);
typedef _SwcFreeDart = void Function(Pointer<Utf8> ptr);
typedef _SwcParseExprC = Pointer<Utf8> Function(Pointer<Utf8> src, Uint8 isTsx);
typedef _SwcParseExprDart = Pointer<Utf8> Function(Pointer<Utf8> src, int isTsx);

class SwcFFI {
  final DynamicLibrary _lib;
  late final _SwcParseTsDart _parse;
  late final _SwcFreeDart _free;
  late final _SwcParseExprDart _parseExpr;

  SwcFFI._(this._lib) {
    _parse = _lib.lookupFunction<_SwcParseTsC, _SwcParseTsDart>('swc_parse_ts');
    _free = _lib.lookupFunction<_SwcFreeC, _SwcFreeDart>('swc_free');
    _parseExpr = _lib.lookupFunction<_SwcParseExprC, _SwcParseExprDart>('swc_parse_expr');
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

  String parse(String src, {bool tsx = false, bool keepComments = true}) {
    final inPtr = src.toNativeUtf8();
    try {
      final outPtr = _parse(inPtr, tsx ? 1 : 0, keepComments ? 1 : 0);
      if (outPtr.address == 0) {
        throw StateError('SWC parse returned null');
      }
      try {
        final s = outPtr.toDartString();
        return s;
      } finally {
        _free(outPtr);
      }
    } finally {
      malloc.free(inPtr);
    }
  }

  String parseExpr(String src, {bool tsx = false}) {
    final inPtr = src.toNativeUtf8();
    try {
      final outPtr = _parseExpr(inPtr, tsx ? 1 : 0);
      if (outPtr.address == 0) {
        throw StateError('SWC parse expr returned null');
      }
      try {
        final s = outPtr.toDartString();
        return s;
      } finally {
        _free(outPtr);
      }
    } finally {
      malloc.free(inPtr);
    }
  }
}
