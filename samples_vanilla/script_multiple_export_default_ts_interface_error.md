# script_multiple_export_default_ts_interface_error

示例：

```vue
<script lang="ts">
interface ComponentProps {
  title: string
  count?: number
}

export default {
  name: 'TsInterfaceComponent1',
  props: {
    title: String,
    count: Number
  } as ComponentProps
}

export default {
  name: 'TsInterfaceComponent2',
  template: '<div>{{ title }}</div>'
}
</script>
```

编译输出：

```ts
interface ComponentProps {
  title: string
  count?: number
}

export default {
  name: 'TsInterfaceComponent1',
  props: {
    title: String,
    count: Number
  } as ComponentProps
}

export default {
  name: 'TsInterfaceComponent2',
  template: '<div>{{ title }}</div>'
}
```

