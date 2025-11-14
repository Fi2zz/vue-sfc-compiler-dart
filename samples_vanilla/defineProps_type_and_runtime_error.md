# defineProps_type_and_runtime_error

示例：

```vue
<script setup lang="ts">
const p = defineProps<{ a: number }>({ a: Number })
</script>
```

错误：

``
[@vue/compiler-sfc] defineProps() cannot accept both type and non-type arguments at the same time. Use one or the other.

./defineProps_type_and_runtime_error.vue
1  |  <script setup lang="ts">
2  |  const p = defineProps<{ a: number }>({ a: Number })
   |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
3  |  </script>
``

