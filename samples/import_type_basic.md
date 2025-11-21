# import_type_basic

```
import { defineComponent as _defineComponent } from 'vue'
import type { Component } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'import_type_basic',
  setup(__props, { expose: __expose }) {
  __expose();

let c: Component | null = null

const __returned__ = { get c() { return c }, set c(v) { c = v } }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

