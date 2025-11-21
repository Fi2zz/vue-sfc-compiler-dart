# script_multiple_export_default_ts_interface_error

```
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

