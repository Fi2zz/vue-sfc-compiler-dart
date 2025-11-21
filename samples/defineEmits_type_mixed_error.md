# defineEmits_type_mixed_error

Vue Compile Error: [@vue/compiler-sfc] defineEmits() type cannot mixed call signature and property syntax.

./defineEmits_type_mixed_error.vue
1  |  <script setup lang="ts">
2  |  const emit = defineEmits<{ (e: 'a'): void; a: any }>()
   |                           ^^^^^^^^^^^^^^^^^^^^^^^^^^
3  |  </script>