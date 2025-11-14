# export_default_error

示例：

```vue
<script setup>
export default { name: 'X' }
</script>
```

错误：

``
[@vue/compiler-sfc] <script setup> cannot contain ES module exports. If you are using a previous version of <script setup>, please consult the updated RFC at https://github.com/vuejs/rfcs/pull/227.

./export_default_error.vue
1  |  <script setup>
   |                 ^
2  |  export default { name: 'X' }
   |  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
3  |  </script>
``

