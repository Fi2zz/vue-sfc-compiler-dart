# getCurrentScope_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { getCurrentScope } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'getCurrentScope_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const scope = getCurrentScope()

const __returned__ = { scope, getCurrentScope }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

