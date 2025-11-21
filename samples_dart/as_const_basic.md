# as_const_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({  __name: 'as_const_basic',
setup(__props: any, { expose: __expose }) {
  __expose();
const cfg = { a: 1 } as const
const __returned__ = { cfg }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
