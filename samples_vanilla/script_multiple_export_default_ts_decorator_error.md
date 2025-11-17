# script_multiple_export_default_ts_decorator_error

示例：

```vue
<script lang="ts">
import { Vue, Component, Prop } from 'vue-property-decorator'

@Component({
  name: 'TsDecoratorComponent1'
})
export default class FirstComponent extends Vue {
  @Prop(String) message!: string
}

@Component({
  name: 'TsDecoratorComponent2'
})
export default class SecondComponent extends Vue {
  @Prop(Number) count!: number
}
</script>
```

编译输出：

```ts
import { Vue, Component, Prop } from 'vue-property-decorator'

@Component({
  name: 'TsDecoratorComponent1'
})
export default class FirstComponent extends Vue {
  @Prop(String) message!: string
}

@Component({
  name: 'TsDecoratorComponent2'
})
export default class SecondComponent extends Vue {
  @Prop(Number) count!: number
}
```

