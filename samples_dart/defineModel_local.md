# defineModel_local

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_local',
setup(__props: any, { expose: __expose }) {
  __expose();

const count = defineModel<number>('count', { local: true })

const __returned__ = { count }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
