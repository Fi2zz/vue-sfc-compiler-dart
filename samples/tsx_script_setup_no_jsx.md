# tsx_script_setup_no_jsx

```
import { defineComponent as _defineComponent } from 'vue'
import { ref } from "vue"

export default /*@__PURE__*/_defineComponent({
  __name: 'tsx_script_setup_no_jsx',
  setup(__props, { expose: __expose }) {
  __expose();

const n = ref(0)

const __returned__ = { n }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
