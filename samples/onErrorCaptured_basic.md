# onErrorCaptured_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { onErrorCaptured } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onErrorCaptured_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onErrorCaptured(() => false)

const __returned__ = { onErrorCaptured }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
