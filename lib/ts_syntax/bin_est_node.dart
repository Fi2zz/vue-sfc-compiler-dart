// Lazy binary view implementing EstNode over the oxc_parse_batch_bin
// tagged format (OXB2). Fields are decoded on first access and memoized;
// keys resolve through the interned key table (no string allocation per
// access), type names through the type table.
//
// Wire layout (little-endian):
//   magic u32 | keyCount u32 | keys(keyCount x len u32 + utf8)
//   typeCount u32 | types(typeCount x len u32 + utf8)
//   itemCount u32 | index(itemCount x off u32, len u32)
//   items...
// value tags: 0 obj(count, pairs[keyId u32, value]) | 8 typedObj(typeId,
// count, pairs minus "type") | 1 arr(count, values) | 2 str(len+utf8) |
// 3 f64 | 7 i64 | 4 true | 5 false | 6 null
import 'dart:convert';
import 'dart:typed_data';

import 'est_node.dart';

class BinCtx {
  BinCtx(Uint8List bytes) : b = bytes;
  final Uint8List b;
  late ByteData v;
  late List<String> keys;
  late Map<String, int> keyIds;
  late List<String> types;
}

/// Batch-level reader: parses tables/index and yields one EstNode payload
/// root per item.
List<EstNode> readBinBatch(Uint8List blob) {
  final ctx = BinCtx(blob);
  ctx.v = ByteData.sublistView(blob);
  var p = 0;
  int u32() {
    final v0 = ctx.v.getUint32(p, Endian.little);
    p += 4;
    return v0;
  }

  String str() {
    final len = u32();
    final s = utf8.decode(Uint8List.sublistView(blob, p, p + len));
    p += len;
    return s;
  }

  if (u32() != 0x4F584232) {
    throw const FormatException('bad bin batch magic');
  }
  final keyCount = u32();
  ctx.keys = List.generate(keyCount, (_) => str());
  ctx.keyIds = {for (var i = 0; i < keyCount; i++) ctx.keys[i]: i};
  final typeCount = u32();
  ctx.types = List.generate(typeCount, (_) => str());
  final itemCount = u32();
  // Index entries are interleaved (off u32, len u32) per item; decoding is
  // driven by offsets.
  final offs = List<int>.generate(itemCount, (_) {
    final off = u32();
    u32(); // length
    return off;
  });
  return [for (final off in offs) _nodeAt(ctx, off)];
}

BinEstNode _nodeAt(BinCtx ctx, int off) {
  final tag = ctx.b[off];
  if (tag != 0 && tag != 8) {
    throw StateError('unexpected payload root tag $tag at $off');
  }
  var p = off + 1;
  var tid = -1;
  if (tag == 8) {
    tid = ctx.v.getUint32(p, Endian.little);
    p += 4;
  }
  final cnt = ctx.v.getUint32(p, Endian.little);
  return BinEstNode._(ctx, tid, p + 4, cnt);
}

dynamic decodeValue(BinCtx ctx, int pos) {
  final tag = ctx.b[pos];
  switch (tag) {
    case 0:
    case 8:
      var p = pos + 1;
      var tid = -1;
      if (tag == 8) {
        tid = ctx.v.getUint32(p, Endian.little);
        p += 4;
      }
      final cnt = ctx.v.getUint32(p, Endian.little);
      return BinEstNode._(ctx, tid, p + 4, cnt);
    case 1:
      var p = pos + 1;
      final cnt = ctx.v.getUint32(p, Endian.little);
      p += 4;
      final out = List<dynamic>.filled(cnt, null);
      for (var i = 0; i < cnt; i++) {
        out[i] = decodeValue(ctx, p);
        p = skipValue(ctx.b, p);
      }
      return out;
    case 2:
      final len = ctx.v.getUint32(pos + 1, Endian.little);
      return utf8.decode(Uint8List.sublistView(ctx.b, pos + 5, pos + 5 + len));
    case 3:
      return ctx.v.getFloat64(pos + 1, Endian.little);
    case 7:
      return ctx.v.getInt64(pos + 1, Endian.little);
    case 4:
      return true;
    case 5:
      return false;
    default:
      return null; // 6
  }
}

int skipValue(Uint8List b, int pos) {
  switch (b[pos]) {
    case 0:
    case 8:
      // Both obj(0) and typedObj(8) carry keyId-prefixed pairs.
      var p = pos + 1;
      if (b[pos] == 8) p += 4;
      final cnt = b[p] | (b[p + 1] << 8) | (b[p + 2] << 16) | (b[p + 3] << 24);
      p += 4;
      for (var i = 0; i < cnt; i++) {
        p += 4; // keyId
        p = skipValue(b, p);
      }
      return p;
    case 1:
      var p = pos + 1;
      final cnt = b[p] | (b[p + 1] << 8) | (b[p + 2] << 16) | (b[p + 3] << 24);
      p += 4;
      for (var i = 0; i < cnt; i++) {
        p = skipValue(b, p);
      }
      return p;
    case 2:
      final len =
          b[pos + 1] |
          (b[pos + 2] << 8) |
          (b[pos + 3] << 16) |
          (b[pos + 4] << 24);
      return pos + 5 + len;
    case 3:
    case 7:
      return pos + 9;
    default:
      return pos + 1;
  }
}

class BinEstNode implements EstNode {
  final BinCtx ctx;
  final int typeId; // -1 for plain objects
  final int entriesPos;
  final int count;
  final Map<int, dynamic> _memo = {};
  final Map<int, int> _pos;
  int? _at;
  int? _endAt;

  BinEstNode._(this.ctx, this.typeId, this.entriesPos, this.count)
    : _pos = _scanPairs(ctx.b, entriesPos, count);

  @override
  String get typeName => ctx.types[typeId];
  @override
  int get at => _at ??= this['start'] as int;
  @override
  int get endAt => _endAt ??= this['end'] as int;

  @override
  dynamic operator [](String key) {
    // typedObj carries its type as a header id, not as a pair.
    if (key == 'type' && typeId >= 0) return ctx.types[typeId];
    final id = ctx.keyIds[key];
    if (id == null) return null;
    final valuePos = _pos[id];
    if (valuePos == null) return null;
    return _memo[id] ??= decodeValue(ctx, valuePos);
  }

  @override
  bool flag(String key) => this[key] == true;
  @override
  bool has(String key) => this[key] != null;
  @override
  String str(String key) => this[key] as String;
  @override
  EstNode nodeOf(Object? v) =>
      v is EstNode ? v : (throw ArgumentError('expected a binary node view'));

  static Map<int, int> _scanPairs(Uint8List b, int pos, int count) =>
      Map.fromEntries(
        List.generate(count, (_) {
          final id =
              b[pos] |
              (b[pos + 1] << 8) |
              (b[pos + 2] << 16) |
              (b[pos + 3] << 24);
          final valuePos = pos + 4;
          pos = skipValue(b, valuePos);
          return MapEntry(id, valuePos);
        }),
      );
}

/// DEBUG helper: decode a single item by batch index.

/// DEBUG helper: decode a single batch item by index.
List<EstNode> readOneBinItem(Uint8List blob, int index) {
  final items = readBinBatch(blob);
  if (index >= items.length) {
    throw StateError('index $index >= ${items.length}');
  }
  return [items[index]];
}
