# defineModel_duplicate_name_error

Vue Compile Error: [@vue/compiler-sfc] duplicate model name "count"

./defineModel_duplicate_name_error.vue
1  |  <script setup lang="ts">
2  |  const a = defineModel<number>('count')
3  |  const b = defineModel<number>('count')
   |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
4  |  </script>