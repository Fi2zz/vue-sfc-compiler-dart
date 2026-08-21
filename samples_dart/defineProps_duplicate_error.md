# defineProps_duplicate_error

Vue Compile Error: [@vue/compiler-sfc] duplicate defineProps() call

./defineProps_duplicate_error.vue
1 | <script setup lang="ts">
2 | const p1 = defineProps<{ a: number }>()
3 | const p2 = defineProps<{ b: string }>()
| ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
4 | </script>
