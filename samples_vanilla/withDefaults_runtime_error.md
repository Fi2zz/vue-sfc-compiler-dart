# withDefaults_runtime_error

示例：

```vue
<script setup lang="ts">
const { a } = withDefaults(defineProps({ a: Number }), { a: 1 })
</script>
```

错误：

``
[@vue/compiler-sfc] withDefaults can only be used with type-based defineProps declaration.

./withDefaults_runtime_error.vue
1  |  <script setup lang="ts">
2  |  const { a } = withDefaults(defineProps({ a: Number }), { a: 1 })
   |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
3  |  </script>
``

