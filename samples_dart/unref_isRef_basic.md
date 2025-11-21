# unref_isRef_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref, unref, isRef } from 'vue';
export default /*@__PURE__*/_defineComponent({  __name: 'unref_isRef_basic',
setup(__props: any, { expose: __expose }) {
  __expose();
const a = ref(1)
const v = unref(a)
const ok = isRef(a)
const __returned__ = { a, v, ok }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
