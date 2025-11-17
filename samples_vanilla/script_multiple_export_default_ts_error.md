# script_multiple_export_default_ts_error

示例：

```vue
<script lang="ts">
import { defineComponent } from 'vue'

export default defineComponent({
  name: 'FirstTsComponent',
  props: {
    message: String
  },
  setup(props) {
    return { greeting: 'Hello ' + props.message }
  }
})

export default defineComponent({
  name: 'SecondTsComponent',
  data() {
    return { count: 0 }
  }
})
</script>
```

编译输出：

```ts
import { defineComponent } from 'vue'

export default defineComponent({
  name: 'FirstTsComponent',
  props: {
    message: String
  },
  setup(props) {
    return { greeting: 'Hello ' + props.message }
  }
})

export default defineComponent({
  name: 'SecondTsComponent',
  data() {
    return { count: 0 }
  }
})
```

