# user_import_script_normal_namespace_vue

```
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

