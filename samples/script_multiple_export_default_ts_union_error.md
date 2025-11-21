# script_multiple_export_default_ts_union_error

```
type Status = 'loading' | 'success' | 'error'

export default {
  name: 'TsUnionComponent1',
  props: {
    status: String as () => Status
  }
}

export default {
  name: 'TsUnionComponent2',
  setup() {
    const currentStatus: Status = 'success'
    return { currentStatus }
  }
}
```

