# defineModel_get_set

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_get_set',
setup(__props: any, { expose: __expose }) {
  __expose();

const value = defineModel<number>('value', { get: (v)=> v, set: (v)=> Math.max(0, v) })

const __returned__ = { value }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
