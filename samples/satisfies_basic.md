# satisfies_basic

```
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'satisfies_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const conf = { a: 1 } satisfies { a: number }

const __returned__ = { conf }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
