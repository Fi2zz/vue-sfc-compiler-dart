# defineModel_local

```
import { useModel as _useModel, defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_local',
  props: {
    "count": { type: Number, ...{ local: true } },
    "countModifiers": {},
  },
  emits: ["update:count"],
  setup(__props, { expose: __expose }) {
  __expose();

const count = _useModel<number>(__props, 'count')

const __returned__ = { count }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
