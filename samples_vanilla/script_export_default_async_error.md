# script_export_default_async_error

示例：

```vue
<script>
export default {
  name: 'SyncComponent'
}

async function loadConfig() {
  return { name: 'AsyncComponent' }
}

export default await loadConfig()
</script>
```

错误：

``
[vue/compiler-sfc] Only one default export allowed per module. (10:0)

./script_export_default_async_error.vue
7  |    return { name: 'AsyncComponent' }
8  |  }
9  |  
   |   ^
10 |  export default await loadConfig()
   |  ^
11 |  </script>
``

