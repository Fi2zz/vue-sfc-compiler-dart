# script_export_default_async_error

Vue Compile Error: [vue/compiler-sfc] Only one default export allowed per module. (10:0)

./script_export_default_async_error.vue
7  |    return { name: 'AsyncComponent' }
8  |  }
9  |  
   |   ^
10 |  export default await loadConfig()
   |  ^
11 |  </script>