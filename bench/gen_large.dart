// Generates synthetic large SFCs into bench/corpus/ for the size-scaling
// tier (see PERF_BENCHMARK.md). Run: dart run bench/gen_large.dart
import 'dart:io';

String _module(int m) =>
    '''
  <fieldset v-if="visible$m">
    <legend>group $m</legend>
    <label v-for="(row, ri) in groups[$m].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[$m].cfg" @change="onPick(\$event, $m)"/>
  </fieldset>
''';

void main() {
  Directory('bench/corpus').createSync(recursive: true);
  for (final mult in [10, 50]) {
    final buf = StringBuffer()
      ..writeln('<script setup lang="ts">')
      ..writeln("import { ref } from 'vue'")
      ..writeln('const locked = false')
      ..writeln('function onPick(e: unknown, m: number) { console.log(e, m) }')
      ..writeln('const groups = Array.from({ length: $mult }, (_, m) =>')
      ..writeln('  ({ rows: [{ id: m, name: "n", kind: "a", cfg: {} }] }))');
    for (var i = 0; i < mult * 4; i++) {
      buf.writeln('const visible$i = ref<boolean>(${i % 2 == 0});');
    }
    buf
      ..writeln('</script>')
      ..writeln('<template>')
      ..writeln('<form>');
    for (var m = 0; m < mult; m++) {
      buf.write(_module(m));
    }
    buf
      ..writeln('</form>')
      ..writeln('</template>')
      ..writeln('<style scoped>');
    for (var m = 0; m < mult * 2; m++) {
      buf.writeln('.g$m > label:nth-child(2n) { color: #$m$m$m }');
    }
    buf.writeln('</style>');
    File('bench/corpus/large_$mult.vue').writeAsStringSync(buf.toString());
    stdout.writeln(
      'bench/corpus/large_$mult.vue ${File('bench/corpus/large_$mult.vue').lengthSync()} bytes',
    );
  }
}
