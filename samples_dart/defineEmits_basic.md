# defineEmits_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineEmits_basic',
  emits: ['update', 'remove'],
setup(__props: any, { expose: __expose }) {
  __expose();

const emit = __emit

const __returned__ = { emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
