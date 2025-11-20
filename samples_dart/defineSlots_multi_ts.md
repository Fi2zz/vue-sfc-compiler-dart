# defineSlots_multi_ts

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineSlots_multi_ts',
setup(__props: any, { expose: __expose }) {
  __expose();

const slots = defineSlots<{ header(): any; default(props:{msg:string}): any; footer(): any }>()

const __returned__ = { slots }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
