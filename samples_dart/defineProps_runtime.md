# defineProps_runtime

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_runtime',
  props: { 
    msg: { type: String, required: false },
    count: { type: { type: Number, required: false },
    default: { type: 0, required: false }
   },
setup(__props: any, { expose: __expose }) {
  __expose();

const props = __props
const props = defineProps({ msg: String, count: { type: Number, default: 0 } })

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
