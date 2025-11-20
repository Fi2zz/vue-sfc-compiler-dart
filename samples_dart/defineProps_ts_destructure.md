# defineProps_ts_destructure

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_ts_destructure',
  props: { 
    msg: { type: String, required: true },
    count: { type: Number, required: false }
   },
setup(__props: any, { expose: __expose }) {
  __expose();

const const { msg = 'hi', count = 1 } = defineProps<{ msg: string; count?: number }>() = __props
const { msg = 'hi', count = 1 } = defineProps<{ msg: string; count?: number }>()

const __returned__ = { msg }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
