# defineModel_required

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_required',
setup(__props: any, { expose: __expose }) {
  __expose();

const visible = defineModel<boolean>('visible', { required: true })

const __returned__ = { visible }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
