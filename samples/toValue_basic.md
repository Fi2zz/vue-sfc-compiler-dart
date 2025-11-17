# toValue_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { toValue, ref } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'toValue_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const a = ref(1)
const v = toValue(a)

const __returned__ = { a, v, toValue, ref }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
