# defineOptions_props_error

Vue Compile Error: [@vue/compiler-sfc] defineOptions() cannot be used to declare props. Use defineProps() instead.

./defineOptions_props_error.vue
1 | <script setup lang="ts">
2 | defineOptions({ name: 'OptsPropsErr', props: { a: String } })
| ^^^^^^^^^^^^^^^^^^^^
3 | </script>
