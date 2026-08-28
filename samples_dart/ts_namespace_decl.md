# ts_namespace_decl

```
import { defineComponent as _defineComponent } from 'vue'
namespace N {
  export type A = string
}

export default /*@__PURE__*/_defineComponent({
  __name: 'ts_namespace_decl',
  setup(__props, { expose: __expose }) {
  __expose();

const y = 2

const __returned__ = { y }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
