# shallowRef_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
import { shallowRef } from 'vue';
export default /*@__PURE__*/_defineComponent({  __name: 'shallowRef_basic',
setup(__props: any, { expose: __expose }) {
  __expose();
const a = shallowRef(1)
const __returned__ = { a }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
