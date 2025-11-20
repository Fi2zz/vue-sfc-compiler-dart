# triggerRef_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
import { shallowRef, triggerRef } from "vue";export default /*@__PURE__*/_defineComponent({
  __name: 'triggerRef_basic',
setup(__props: any, { expose: __expose }) {
  __expose();

triggerRef(r)
const r = shallowRef(1)

const __returned__ = { r }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
