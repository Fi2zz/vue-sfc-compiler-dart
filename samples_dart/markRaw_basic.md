# markRaw_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { markRaw } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'markRaw_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const obj = markRaw({ a: 1 })

const __returned__ = { obj, markRaw }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
