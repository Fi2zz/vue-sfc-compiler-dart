# defineOptions_duplicate_error

示例：

```vue
<script setup lang="ts">
defineOptions({ name: 'X1' })
defineOptions({ name: 'X2' })
</script>
```

错误：

``
[@vue/compiler-sfc] duplicate defineOptions() call

./defineOptions_duplicate_error.vue
1  |  <script setup lang="ts">
2  |  defineOptions({ name: 'X1' })
   |                                ^
3  |  defineOptions({ name: 'X2' })
   |  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
4  |  </script>
``

