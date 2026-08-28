# script_normal_after_setup

```
import { ref } from 'vue'

const __default__ = {
  name: 'ScriptOrder',
  inheritAttrs: false,
}


export default /*@__PURE__*/Object.assign(__default__, {
  setup(__props, { expose: __expose }) {
  __expose();

const count = ref(1)
console.log('setup side effect')

const __returned__ = { count, ref }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
