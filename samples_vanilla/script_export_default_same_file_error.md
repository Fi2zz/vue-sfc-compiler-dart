# script_export_default_same_file_error

示例：

```vue
<script>
const firstConfig = {
  name: 'FirstConfig',
  template: '<div>First</div>'
}

const secondConfig = {
  name: 'SecondConfig',
  template: '<div>Second</div>'
}

export default firstConfig
export default secondConfig
</script>
```

错误：

``
[vue/compiler-sfc] Only one default export allowed per module. (13:0)

./script_export_default_same_file_error.vue
10 |  }
11 |  
12 |  export default firstConfig
   |                             ^
13 |  export default secondConfig
   |  ^
14 |  </script>
``

