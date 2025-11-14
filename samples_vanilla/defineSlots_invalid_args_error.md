# defineSlots_invalid_args_error

示例：

```vue
<script setup lang="ts">
defineSlots({})
</script>
```

错误：

``
[@vue/compiler-sfc] defineSlots() cannot accept arguments

./defineSlots_invalid_args_error.vue
1  |  <script setup lang="ts">
   |                           ^
2  |  defineSlots({})
   |  ^^^^^^^^^^^^^^^
3  |  </script>
``

