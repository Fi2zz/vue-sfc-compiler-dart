# defineModel_named_default_fn

示例：

```vue
<script setup lang="ts">
const config = defineModel<{ a: number }>('config', { default: () => ({ a: 1 }) })
</script>
```

编译输出：

```ts
import { useModel as _useModel, defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_named_default_fn',
  props: {
    "config": { type: Object, ...{ default: () => ({ a: 1 }) } },
    "configModifiers": {},
  },
  emits: ["update:config"],
  setup(__props, { expose: __expose }) {
  __expose();

const config = _useModel<{ a: number }>(__props, 'config')

const __returned__ = { config }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

