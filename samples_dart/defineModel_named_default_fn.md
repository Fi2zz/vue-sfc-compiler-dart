# defineModel_named_default_fn

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_named_default_fn',
setup(__props: any, { expose: __expose }) {
  __expose();

const config = defineModel<{ a: number }>('config', { default: () => ({ a: 1 }) })

const __returned__ = { config }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
