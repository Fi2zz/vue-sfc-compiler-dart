# script_export_default_conditional_error

示例：

```vue
<script>
const isDev = process.env.NODE_ENV === 'development'

export default isDev ? {
  name: 'DevComponent',
  template: '<div>Development</div>'
} : {
  name: 'ProdComponent',
  template: '<div>Production</div>'
}

export default {
  name: 'FallbackComponent'
}
</script>
```

错误：

``
[vue/compiler-sfc] Only one default export allowed per module. (12:0)

./script_export_default_conditional_error.vue
9  |    template: '<div>Production</div>'
10 |  }
11 |  
   |   ^
12 |  export default {
   |  ^
13 |    name: 'FallbackComponent'
``

