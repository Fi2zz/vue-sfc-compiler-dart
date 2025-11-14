# defineOptions_type_args_error

Vue Compile Error: [@vue/compiler-sfc] defineOptions() cannot accept type arguments

./defineOptions_type_args_error.vue
1 | <script setup lang="ts">
| ^
2 | defineOptions<{}>({ name: 'X' })
| ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
3 | </script>
