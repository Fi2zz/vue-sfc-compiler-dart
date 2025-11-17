# script_multiple_export_default_error

示例：

```vue
<script>
export default {
  name: 'FirstDefault'
}

export default {
  name: 'SecondDefault'
}
</script>
```

错误：

``
[vue/compiler-sfc] Only one default export allowed per module. (6:0)

./script_multiple_export_default_error.vue
3  |    name: 'FirstDefault'
4  |  }
5  |  
   |   ^
6  |  export default {
   |  ^
7  |    name: 'SecondDefault'
``

