# defineProps_runtime_default_fn

示例：

```vue
<script setup lang="ts">
const props = defineProps({ items: { type: Array, default: ()=> [] } })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_runtime_default_fn',
  props: { items: { type: Array, default: ()=> [] } },
  setup(__props, { expose: __expose }) {
  __expose();

const props = __props

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

