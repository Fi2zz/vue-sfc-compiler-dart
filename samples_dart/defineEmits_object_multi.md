# defineEmits_object_multi

```ts
import { defineComponent as _defineComponent, mergeModels as _mergeModels } from 'vue'
export default /*@__PURE__*/_defineComponent({  __name: 'defineEmits_object_multi',
  emits: ['save'],

setup(__props: any, { expose: __expose, emit: __emit }) {
  __expose();
const emit = __emit;

emit('save', { id: 1 })
emit('cancel')
const __returned__ = { emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
