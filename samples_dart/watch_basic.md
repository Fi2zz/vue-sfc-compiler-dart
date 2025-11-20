# watch_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref, watch } from "vue";export default /*@__PURE__*/_defineComponent({
  __name: 'watch_basic',
setup(__props: any, { expose: __expose }) {
  __expose();

watch(v, (nv, ov) => {})
const v = ref(0)

const __returned__ = { v }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
