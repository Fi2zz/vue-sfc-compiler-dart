# defineModel_duplicate_name_error

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_duplicate_name_error',
setup(__props: any, { expose: __expose }) {
  __expose();

const a = defineModel<number>('count')
const b = defineModel<number>('count')

const __returned__ = { a, b }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
