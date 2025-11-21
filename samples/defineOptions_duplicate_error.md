# defineOptions_duplicate_error

Vue Compile Error: [@vue/compiler-sfc] duplicate defineOptions() call

./defineOptions_duplicate_error.vue
1  |  <script setup lang="ts">
2  |  defineOptions({ name: 'X1' })
   |                                ^
3  |  defineOptions({ name: 'X2' })
   |  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
4  |  </script>