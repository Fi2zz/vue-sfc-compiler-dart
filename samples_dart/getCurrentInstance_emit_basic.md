# getCurrentInstance_emit_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
import { getCurrentInstance } from "vue";export default /*@__PURE__*/_defineComponent({
  __name: 'getCurrentInstance_emit_basic',
setup(__props: any, { expose: __expose }) {
  __expose();

const inst = getCurrentInstance()

const __returned__ = { inst }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
