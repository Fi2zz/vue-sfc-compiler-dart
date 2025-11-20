# withDefaults_typed_destructure

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'withDefaults_typed_destructure',
  props: { 
    msg: { type: String, required: false , default: 'hi' },
    count: { type: Number, required: false , default: 1 }
   },
setup(__props: any, { expose: __expose }) {
  __expose();

const const { msg, count } = withDefaults(defineProps<{ msg?: string; count?: number }>(), { msg: 'hi', count: 1 }) = __props
const { msg, count } = withDefaults(defineProps<{ msg?: string; count?: number }>(), { msg: 'hi', count: 1 })

const __returned__ = { msg }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
