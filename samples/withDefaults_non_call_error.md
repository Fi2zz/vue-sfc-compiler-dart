# withDefaults_non_call_error

Vue Compile Error: [@vue/compiler-sfc] withDefaults' first argument must be a defineProps call.

./withDefaults_non_call_error.vue
1 | <script setup lang="ts">
2 | const foo = {} as any
3 | const { a } = withDefaults(foo, { a: 1 })
| ^^^
4 | </script>
