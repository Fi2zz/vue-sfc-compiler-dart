# script_multiple_export_default_ts_module_error

示例：

```vue
<script lang="ts">
namespace ComponentNamespace {
  export interface Props {
    id: number
    label: string
  }
}

export default {
  name: 'TsModuleComponent1',
  props: {
    id: Number,
    label: String
  } as ComponentNamespace.Props
}

export default {
  name: 'TsModuleComponent2',
  template: '<div>{{ label }}</div>'
}
</script>
```

编译输出：

```ts
namespace ComponentNamespace {
  export interface Props {
    id: number
    label: string
  }
}

export default {
  name: 'TsModuleComponent1',
  props: {
    id: Number,
    label: String
  } as ComponentNamespace.Props
}

export default {
  name: 'TsModuleComponent2',
  template: '<div>{{ label }}</div>'
}
```

