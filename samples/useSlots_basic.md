# useSlots_basic

```
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'useSlots_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const slots = useSlots()

const __returned__ = { slots }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

