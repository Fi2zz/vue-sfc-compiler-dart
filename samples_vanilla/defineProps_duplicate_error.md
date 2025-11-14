# defineProps_duplicate_error

示例：

```vue
<script setup lang="ts">
const p1 = defineProps<{ a: number }>()
const p2 = defineProps<{ b: string }>()
</script>
```

错误：

``
[@vue/compiler-sfc] duplicate defineProps() call

./defineProps_duplicate_error.vue
1  |  <script setup lang="ts">
2  |  const p1 = defineProps<{ a: number }>()
3  |  const p2 = defineProps<{ b: string }>()
   |             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
4  |  </script>
``

