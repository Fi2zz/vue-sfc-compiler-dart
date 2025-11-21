# toRef_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { reactive, toRef } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'toRef_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const s = reactive({ a: 1 })
const a = toRef(s, 'a')

const __returned__ = { s, a, reactive, toRef }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

