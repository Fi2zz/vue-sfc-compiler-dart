# defineEmits_type_mixed_error

示例：

```vue
<script setup lang="ts">
const emit = defineEmits<{ (e: 'a'): void; a: any }>()
</script>
```

错误：

``
[@vue/compiler-sfc] defineEmits() type cannot mixed call signature and property syntax.

./defineEmits_type_mixed_error.vue
1  |  <script setup lang="ts">
2  |  const emit = defineEmits<{ (e: 'a'): void; a: any }>()
   |                           ^^^^^^^^^^^^^^^^^^^^^^^^^^
3  |  </script>
``

