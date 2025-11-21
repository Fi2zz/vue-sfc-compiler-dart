# onRenderTracked_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { onRenderTracked } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onRenderTracked_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onRenderTracked(() => {})

const __returned__ = { onRenderTracked }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

