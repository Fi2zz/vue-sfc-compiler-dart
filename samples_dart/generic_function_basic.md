# generic_function_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({  __name: 'generic_function_basic',
setup(__props: any, { expose: __expose }) {
  __expose();
function id<T>(x: T): T { return x }
const n = id(1)
const __returned__ = { id, n }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
