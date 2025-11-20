# reactive_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
import { reactive } from "vue";export default /*@__PURE__*/_defineComponent({
  __name: 'reactive_basic',
setup(__props: any, { expose: __expose }) {
  __expose();

const state = reactive({ count: 0 })

const __returned__ = { state }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
