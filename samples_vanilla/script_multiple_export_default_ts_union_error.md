# script_multiple_export_default_ts_union_error

示例：

```vue
<script lang="ts">
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
</script>
```

编译输出：

```ts
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

