import 'dart:io';

import 'package:vue_sfc_parser/sfc_compile_script.dart';
import 'package:vue_sfc_parser/sfc_parser.dart';

const filename = "./vue_complex.vue";
// ignore: non_constant_identifier_names
File vue_complex = File(filename);
File outfile = File("vue_complex_dart.md");

class Sample {
  final String name;
  final String sfc;
  Sample({required this.name, required this.sfc});
  static Sample fromJson(Map<String, dynamic> json) {
    return Sample(name: json['name'] as String, sfc: json['sfc'] as String);
  }
}

Future<void> main() async {
  try {
    final raw = vue_complex.readAsStringSync();

    final parser = SfcParser(raw, filename: filename);

    final descriptor = parser.parse();

    String code = compileScript(descriptor).trim();

    String md =
        """
```ts\n$code\n```
"""
            .trim();
    outfile.writeAsString(md);
  } catch (error) {
    print('error $error');
  }
}
