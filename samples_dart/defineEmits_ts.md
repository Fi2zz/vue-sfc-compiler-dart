# defineEmits_ts

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineEmits_ts',
setup(__props: any, { expose: __expose }) {
  __expose();

const emit = __emit
emit('remove')
emit('update', 1)
const emit = defineEmits<{ (e:'update', id: number): void; (e:'remove'): void }>()

const __returned__ = { emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
