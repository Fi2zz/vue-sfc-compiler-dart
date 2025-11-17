# script_multiple_export_default_ts_type_alias_error

示例：

```vue
<script lang="ts">
type User = {
  id: number
  name: string
}

export default {
  name: 'TsTypeComponent1',
  setup() {
    const user: User = { id: 1, name: 'John' }
    return { user }
  }
}

export default {
  name: 'TsTypeComponent2',
  props: {
    user: Object as () => User
  }
}
</script>
```

编译输出：

```ts
type User = {
  id: number
  name: string
}

export default {
  name: 'TsTypeComponent1',
  setup() {
    const user: User = { id: 1, name: 'John' }
    return { user }
  }
}

export default {
  name: 'TsTypeComponent2',
  props: {
    user: Object as () => User
  }
}
```

