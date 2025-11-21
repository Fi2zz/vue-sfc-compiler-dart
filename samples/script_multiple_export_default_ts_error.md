# script_multiple_export_default_ts_error

```
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

