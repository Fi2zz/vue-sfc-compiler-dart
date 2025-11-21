# useCssVars_basic

```
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'useCssVars_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const color = 'red'
useCssVars(() => ({ color }))

const __returned__ = { color }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

