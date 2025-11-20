# defineEmits_type_mixed_error

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineEmits_type_mixed_error',
setup(__props: any, { expose: __expose }) {
  __expose();

const emit = __emit
const emit = defineEmits<{ (e: 'a'): void; a: any }>()

const __returned__ = { emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
