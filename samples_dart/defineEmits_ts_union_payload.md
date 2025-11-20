# defineEmits_ts_union_payload

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineEmits_ts_union_payload',
setup(__props: any, { expose: __expose }) {
  __expose();

const emit = __emit
emit('select', { id: 1 })
const emit = defineEmits<{ (e:'select', payload: { id: number } | { slug: string }): void }>()

const __returned__ = { emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
