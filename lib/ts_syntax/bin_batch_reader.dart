// Decoder for the oxc_parse_batch_bin tagged encoding (see worker
// lib.rs header comment). Produces the same Map<String, dynamic> /
// List / String / num / bool shapes jsonDecode would, so downstream
// consumers (OxcMapper) stay untouched.
import 'dart:convert';
import 'dart:typed_data';

class BinBatchReader {
  final Uint8List bytes;
  final ByteData view;
  int pos = 0;

  BinBatchReader(this.bytes) : view = ByteData.sublistView(bytes);

  List<Map<String, dynamic>> readItems() {
    if (_u32() != 0x4F584231) {
      throw ArgumentError('bad binary batch magic');
    }
    final count = _u32();
    pos += count * 8; // skip index; items follow sequentially
    return [for (var i = 0; i < count; i++) _value() as Map<String, dynamic>];
  }

  int _u32() {
    final v = view.getUint32(pos, Endian.little);
    pos += 4;
    return v;
  }

  String _str() {
    final len = _u32();
    final s = utf8.decode(bytes.sublist(pos, pos + len));
    pos += len;
    return s;
  }

  dynamic _value() {
    final tag = bytes[pos++];
    switch (tag) {
      case 0:
        final n = _u32();
        return {
          for (var i = 0; i < n; i++) _str(): _value(),
        };
      case 1:
        final n = _u32();
        return [for (var i = 0; i < n; i++) _value()];
      case 2:
        return _str();
      case 3:
        final v = view.getFloat64(pos, Endian.little);
        pos += 8;
        return v;
      case 7:
        final v = view.getInt64(pos, Endian.little);
        pos += 8;
        return v;
      case 4:
        return true;
      case 5:
        return false;
      case 6:
        return null;
      default:
        throw ArgumentError('bad binary tag $tag at ${pos - 1}');
    }
  }
}
