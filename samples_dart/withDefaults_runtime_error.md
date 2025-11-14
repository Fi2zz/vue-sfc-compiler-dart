# withDefaults_runtime_error

Vue Compile Error: [@vue/compiler-sfc] withDefaults() only works with typed defineProps()

./withDefaults_runtime_error.vue
1 | <script setup lang="ts">
| ^
2 | withDefaults(defineProps({}), {})
| ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
3 | </script>
