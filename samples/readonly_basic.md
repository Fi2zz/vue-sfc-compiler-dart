# readonly_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { readonly, reactive } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'readonly_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const s = readonly(reactive({ a: 1 }))

const __returned__ = { s, readonly, reactive }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
