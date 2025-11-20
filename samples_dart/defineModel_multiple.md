# defineModel_multiple

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_multiple',
setup(__props: any, { expose: __expose }) {
  __expose();

const title = defineModel<string>()
const checked = defineModel<boolean>('checked')

const __returned__ = { title, checked }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
