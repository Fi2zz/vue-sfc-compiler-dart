# defineEmits_duplicate_error

示例：

```vue
<script setup lang="ts">
const e1 = defineEmits(['a'])
const e2 = defineEmits(['b'])
</script>
```

错误：

``
[@vue/compiler-sfc] duplicate defineEmits() call

./defineEmits_duplicate_error.vue
1  |  <script setup lang="ts">
2  |  const e1 = defineEmits(['a'])
3  |  const e2 = defineEmits(['b'])
   |             ^^^^^^^^^^^^^^^^^^
4  |  </script>
``

