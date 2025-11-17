# defineProps_type_and_runtime_error

[vue/compiler-sfc] defineProps() cannot mix type arguments with runtime props object

./defineProps_type_and_runtime_error.vue
1 | <script setup lang="ts">
| ^
2 | defineProps<{ a: number }>({ a: Number })
| ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
3 | </script>
