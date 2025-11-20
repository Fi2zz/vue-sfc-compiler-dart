# useAttrs_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'useAttrs_basic',
setup(__props: any, { expose: __expose }) {
  __expose();

const attrs = useAttrs()

const __returned__ = { attrs }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
