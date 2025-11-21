# defineSlots_basic

```
import { useSlots as _useSlots } from 'vue'

export default {
  __name: 'defineSlots_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const slots = _useSlots()

const __returned__ = { slots }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

