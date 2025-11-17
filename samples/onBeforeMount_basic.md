# onBeforeMount_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { onBeforeMount } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onBeforeMount_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onBeforeMount(() => {})

const __returned__ = { onBeforeMount }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
