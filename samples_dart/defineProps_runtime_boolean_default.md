# defineProps_runtime_boolean_default

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_runtime_boolean_default',
  props: { 
    enabled: { type: { type: Boolean, required: false },
    default: { type: true, required: false }
   },
setup(__props: any, { expose: __expose }) {
  __expose();

const props = __props
const props = defineProps({ enabled: { type: Boolean, default: true } })

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
