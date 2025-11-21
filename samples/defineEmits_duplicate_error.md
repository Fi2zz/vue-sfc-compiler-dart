# defineEmits_duplicate_error

Vue Compile Error: [@vue/compiler-sfc] duplicate defineEmits() call

./defineEmits_duplicate_error.vue
1  |  <script setup lang="ts">
2  |  const e1 = defineEmits(['a'])
3  |  const e2 = defineEmits(['b'])
   |             ^^^^^^^^^^^^^^^^^^
4  |  </script>