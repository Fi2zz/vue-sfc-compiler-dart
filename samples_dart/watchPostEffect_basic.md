# watchPostEffect_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref, watchPostEffect } from 'vue';
export default /*@__PURE__*/_defineComponent({  __name: 'watchPostEffect_basic',
setup(__props: any, { expose: __expose }) {
  __expose();
const v = ref(0)
watchPostEffect(() => { v.value })
const __returned__ = { v }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
