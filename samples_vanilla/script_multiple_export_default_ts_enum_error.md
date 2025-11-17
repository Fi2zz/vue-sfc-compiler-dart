# script_multiple_export_default_ts_enum_error

示例：

```vue
<script lang="ts">
enum ComponentType {
  PRIMARY = 'primary',
  SECONDARY = 'secondary'
}

export default {
  name: 'TsEnumComponent1',
  setup() {
    const type = ComponentType.PRIMARY
    return { type }
  }
}

export default {
  name: 'TsEnumComponent2',
  data() {
    return {
      availableTypes: Object.values(ComponentType)
    }
  }
}
</script>
```

编译输出：

```ts
enum ComponentType {
  PRIMARY = 'primary',
  SECONDARY = 'secondary'
}

export default {
  name: 'TsEnumComponent1',
  setup() {
    const type = ComponentType.PRIMARY
    return { type }
  }
}

export default {
  name: 'TsEnumComponent2',
  data() {
    return {
      availableTypes: Object.values(ComponentType)
    }
  }
}
```

