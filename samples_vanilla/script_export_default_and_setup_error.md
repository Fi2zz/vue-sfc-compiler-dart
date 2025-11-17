# script_export_default_and_setup_error

示例：

```vue
<script>
export default {
  name: 'ComponentWithSetup',
  setup() {
    return { message: 'hello' }
  }
}

export default {
  name: 'AnotherDefault'
}
</script>
```

错误：

``
[vue/compiler-sfc] Only one default export allowed per module. (9:0)

./script_export_default_and_setup_error.vue
6  |    }
7  |  }
8  |  
   |   ^
9  |  export default {
   |  ^
10 |    name: 'AnotherDefault'
``

