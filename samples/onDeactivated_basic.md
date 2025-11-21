# onDeactivated_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { onDeactivated } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onDeactivated_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onDeactivated(() => {})

const __returned__ = { onDeactivated }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

