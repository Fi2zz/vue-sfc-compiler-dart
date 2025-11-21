# defineEmits_duplicate_error

```ts
import { defineComponent as _defineComponent, mergeModels as _mergeModels } from 'vue'
export default /*@__PURE__*/_defineComponent({  __name: 'defineEmits_duplicate_error',
  emits: ['a'],

setup(__props: any, { expose: __expose, emit: __emit }) {
  __expose();
const e1 = __emit;

const e2 = __emit;

const __returned__ = { e1, e2 }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
