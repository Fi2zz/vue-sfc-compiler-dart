# withDefaults_runtime_error

Vue Compile Error: [@vue/compiler-sfc] withDefaults can only be used with type-based defineProps declaration.

./withDefaults_runtime_error.vue
1  |  <script setup lang="ts">
2  |  const { a } = withDefaults(defineProps({ a: Number }), { a: 1 })
   |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
3  |  </script>