# onActivated_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { onActivated } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onActivated_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onActivated(() => {})

const __returned__ = { onActivated }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
