# defineProps_ts_literal_union_destructure

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_ts_literal_union_destructure',
  props: { 
    size: { type: Object, required: true }
   },
setup(__props: any, { expose: __expose }) {
  __expose();

const const { size = 'medium' } = defineProps<{ size: 'small' | 'medium' | 'large' }>() = __props
const { size = 'medium' } = defineProps<{ size: 'small' | 'medium' | 'large' }>()

const __returned__ = { size }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
