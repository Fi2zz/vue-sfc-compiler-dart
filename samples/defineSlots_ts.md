# defineSlots_ts

```
import { useSlots as _useSlots, defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineSlots_ts',
  setup(__props, { expose: __expose }) {
  __expose();

const slots = _useSlots()

const __returned__ = { slots }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
