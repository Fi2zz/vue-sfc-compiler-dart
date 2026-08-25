import '../lib/template/compile_template.dart';

void main(List<String> args) {
  final r = compileTemplateSource(args[0],
      filename: './p.vue', id: './p.vue');
  if (r.errors.isNotEmpty) {
    print('ERR:${r.errors.first.message}');
  } else {
    print(r.code.trim().split('\n').last);
  }
}
