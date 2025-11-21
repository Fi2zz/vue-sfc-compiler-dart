# user_import_script_normal_namespace_vue

示例：

```vue
<script lang="ts">
import * as vue from 'vue'
import dayjs from 'dayjs'
export default {
  name: 'NsVue',
  mounted() {
    const now = dayjs()
    const c = vue.ref(1)
  }
}
</script>
```

编译输出：

```ts
import * as vue from 'vue'
import dayjs from 'dayjs'
export default {
  name: 'NsVue',
  mounted() {
    const now = dayjs()
    const c = vue.ref(1)
  }
}
```

