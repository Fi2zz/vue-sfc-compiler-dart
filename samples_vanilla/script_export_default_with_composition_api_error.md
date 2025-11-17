# script_export_default_with_composition_api_error

示例：

```vue
<script>
import { ref } from 'vue'

export default {
  name: 'FirstComposition',
  setup() {
    const count = ref(0)
    return { count }
  }
}

export default {
  name: 'SecondComposition',
  setup() {
    const message = ref('hello')
    return { message }
  }
}
</script>
```

错误：

``
[vue/compiler-sfc] Only one default export allowed per module. (12:0)

./script_export_default_with_composition_api_error.vue
9  |    }
10 |  }
11 |  
   |   ^
12 |  export default {
   |  ^
13 |    name: 'SecondComposition',
``

