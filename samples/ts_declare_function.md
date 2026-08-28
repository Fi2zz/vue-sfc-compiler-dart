# ts_declare_function

```
import { defineComponent as _defineComponent } from 'vue'
declare function gtag(...args: any[]): void

export default /*@__PURE__*/_defineComponent({
  __name: 'ts_declare_function',
  setup(__props, { expose: __expose }) {
  __expose();

const x = 1

const __returned__ = { x }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
