# script_export_default_mixed_options_error

示例：

```vue
<script>
export default {
  name: 'FirstComponent',
  data() {
    return { count: 0 }
  }
}

export default {
  name: 'SecondComponent',
  props: ['message']
}
</script>
```

错误：

``
[vue/compiler-sfc] Only one default export allowed per module. (9:0)

./script_export_default_mixed_options_error.vue
6  |    }
7  |  }
8  |  
   |   ^
9  |  export default {
   |  ^
10 |    name: 'SecondComponent',
``

