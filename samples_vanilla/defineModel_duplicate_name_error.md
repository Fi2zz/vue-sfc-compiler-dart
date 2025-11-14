# defineModel_duplicate_name_error

示例：

```vue
<script setup lang="ts">
const a = defineModel<number>('count')
const b = defineModel<number>('count')
</script>
```

错误：

``
[@vue/compiler-sfc] duplicate model name "count"

./defineModel_duplicate_name_error.vue
1  |  <script setup lang="ts">
2  |  const a = defineModel<number>('count')
3  |  const b = defineModel<number>('count')
   |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
4  |  </script>
``

