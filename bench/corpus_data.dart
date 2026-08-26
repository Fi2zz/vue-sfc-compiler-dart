// Benchmark corpus tiers that are not derived from batch_inputs.json.
// Used by bench/bench.dart; large tiers come from bench/gen_large.dart.

const tinyCorpus = <String>[
  "<script setup>\nconst msg = 'hi'\n</script>\n<template><div>{{ msg }}</div></template>",
  '<template><p/></template>',
  '<style scoped>\n.a { color: red; }\n</style>',
  "<script setup>\nimport { ref } from 'vue'\nconst n = ref(1)\n</script>",
  "<script setup>\nconst x = 1\n</script>\n<template><span :class=\"x ? 'a' : 'b'\">t</span></template>\n<style>.b{color:blue}</style>",
];

final tsHeavyCorpus = <String>[
  "<script setup lang=\"ts\">\ninterface Base { id: number; [k: string]: unknown }\ninterface Named extends Base { name?: string }\nconst props = defineProps<{ items: Named[]; callback: (a: string, b?: number) => void }>()\n</script>\n<template><ul><li v-for=\"it in props.items\" :key=\"it.id\">{{ it.name }}</li></ul></template>",
  "<script setup lang=\"ts\">\ntype Mode = 'a' | 'b' | 'c'\nconst { mode = 'a', size } = defineProps<{ mode?: Mode; size?: 's' | 'l' }>()\n</script>\n<template><i>{{ mode }}{{ size }}</i></template>",
  "<script setup lang=\"ts\">\nconst emit = defineEmits<{ (e: 'change', v: number): void; (e: 'reset'): void }>()\n</script>\n<template><button @click=\"emit('change', 1)\"/></template>",
  "<script setup lang=\"ts\">\nimport { reactive } from 'vue'\nconst st = reactive<{ list: { v: number }[] }>({ list: [] })\n</script>\n<template><p v-for=\"x in st.list\" :key=\"x.v\">{{ x.v }}</p></template>",
  "<script setup lang=\"ts\">\nwithDefaults(defineProps<{ msg?: string; count?: number; flags?: string[] }>(), { msg: 'hi', flags: () => [] })\n</script>\n<template><em>{{ msg }}{{ count }}{{ flags }}</em></template>",
];

String _tmplHeavySource(String tag, int rows) =>
    '''
<script setup>
import { ref } from 'vue'
const rows = ref(Array.from({ length: $rows }, (_, i) => ({ id: i, ok: i % 2 === 0, tags: ['a', 'b', 'c'] })))
const sel = ref(null)
</script>
<template>
  <section class="tbl">
    <table>
      <thead><tr><th v-for="h in ['id', 'ok', 'tags']" :key="h">{{ h }}</th></tr></thead>
      <tbody>
        <template v-for="r in rows" :key="r.id">
          <tr v-if="r.ok" :class="{ sel: sel === r.id }" @click="sel = r.id">
            <td>{{ r.id }}</td>
            <td><span v-for="t in r.tags" :key="t" class="tag">{{ t }}</span></td>
            <td><input v-model="r.id" type="number"></td>
          </tr>
          <tr v-else><td colspan="3">skipped {{ r.id }}</td></tr>
        </template>
      </tbody>
    </table>
    <$tag data-x="1"/>
  </section>
</template>
<style scoped>
.tbl { color: #333 }
.tag { border: 1px solid #eee }
.sel { background: #ffa }
</style>
''';

final tmplHeavyCorpus = List.generate(5, (i) {
  final tag = i.isEven ? 'KeepAlive' : 'Transition';
  return _tmplHeavySource(tag, 60 + i * 30);
});

const errorCorpus = <String>[
  '<template><div><span>unclosed</div></template>',
  '<script setup>\nconst x = \n</script>',
  '<template><input v-model></template>',
  '<template><a :[oops /></template>',
  '<template></div></template>',
];
