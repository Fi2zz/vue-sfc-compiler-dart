import 'dart:convert';
import 'dart:io';

import 'package:vue_sfc_parser/sfc_compile_script.dart';
import 'package:vue_sfc_parser/sfc_parser.dart';
import 'package:vue_sfc_parser/sfc_descriptor.dart';

class Sample {
  final String name;
  final String sfc;
  Sample({required this.name, required this.sfc});
  static Sample fromJson(Map<String, dynamic> json) {
    return Sample(name: json['name'] as String, sfc: json['sfc'] as String);
  }
}

Future<void> main() async {
  final samplesFile = File('samples.json');
  if (!samplesFile.existsSync()) {
    stderr.writeln('samples.json not found');
    exitCode = 1;
    return;
  }

  final raw = samplesFile.readAsStringSync();
  final list = jsonDecode(raw) as List<dynamic>;
  final samples = list
      .map((e) => Sample.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);

  await Directory('samples_dart').create(recursive: true);

  for (final s in samples) {
    final filename = './${s.name}.vue';
    try {
      final parser = SfcParser(s.sfc, filename: filename);
      final descriptor = parser.parse();
      String code = compileScript(descriptor).trim();
      final buf = StringBuffer();
      buf.writeln('# ${s.name}\n');
      if (code.isNotEmpty) {
        final lang = _detectLang(descriptor);
        buf.writeln(lang.isEmpty ? '```' : '```$lang');
        buf.writeln(code);
        buf.writeln('```');
      }
      final out = File('samples_dart/${s.name}.md');
      await out.writeAsString(buf.toString());
      // Write root file for vue_complex by parsed generation (no hardcode copy)
      if (s.name == 'vue_complex') {
        final rootOut = File('vue_complex_dart.md');
        final md = StringBuffer();
        final lang = _detectLang(descriptor);
        md.writeln(lang.isEmpty ? '```' : '```$lang');
        md.writeln(code);
        md.writeln('```');
        await rootOut.writeAsString(md.toString());
      }
      // ignore: empty_catches
    } catch (e) {
      final out = File('samples_dart/${s.name}.md');
      final buf = StringBuffer();
      buf.writeln('# ${s.name}\n');
      buf.writeln(e.toString());
      await out.writeAsString(buf.toString());
    }
  }
}

String _detectLang(SfcDescriptor d) {
  final setupLang = d.scriptSetup?.lang?.trim();
  final scriptLang = d.script?.lang?.trim();
  final lang = setupLang?.isNotEmpty == true ? setupLang! : (scriptLang ?? '');
  switch (lang) {
    case 'ts':
    case 'tsx':
      return 'ts';
    case 'js':
    case 'jsx':
      return 'js';
    default:
      return '';
  }
}

// removed: line count padding helper
