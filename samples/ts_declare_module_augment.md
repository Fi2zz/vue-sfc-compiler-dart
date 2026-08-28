# ts_declare_module_augment

```
import { defineComponent as _defineComponent } from 'vue'
declare module '@/types' {
  interface Window { v: number }
}

export default /*@__PURE__*/_defineComponent({
  __name: 'ts_declare_module_augment',
  setup(__props, { expose: __expose }) {
  __expose();

const z = 3

const __returned__ = { z }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
