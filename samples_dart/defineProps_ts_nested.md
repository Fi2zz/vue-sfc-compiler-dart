# defineProps_ts_nested

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_ts_nested',
  props: { 
    user: { type: Object, required: true },
    roles: { type: Object, required: true }
   },
setup(__props: any, { expose: __expose }) {
  __expose();

const props = __props
const props = defineProps<{ user: { name: string; roles: string[] } }>()

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
