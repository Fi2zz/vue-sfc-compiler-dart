# withDefaults_non_call_error

示例：

```vue
<script setup lang="ts">
const foo = {} as any
const { a } = withDefaults(foo, { a: 1 })
</script>
```

错误：

``
[@vue/compiler-sfc] withDefaults' first argument must be a defineProps call.

./withDefaults_non_call_error.vue
1  |  <script setup lang="ts">
2  |  const foo = {} as any
3  |  const { a } = withDefaults(foo, { a: 1 })
   |                             ^^^
4  |  </script>
``

