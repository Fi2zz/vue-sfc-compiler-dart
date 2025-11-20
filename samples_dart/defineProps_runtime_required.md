# defineProps_runtime_required

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_runtime_required',
  props: { 
    count: { type: { type: Number, required: false },
    required: { type: true, required: false }
   },
setup(__props: any, { expose: __expose }) {
  __expose();

const props = __props
const props = defineProps({ count: { type: Number, required: true } })

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
