# user_import_script_setup_namespace_vue

```
import { defineComponent as _defineComponent } from 'vue'
import * as vue from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'user_import_script_setup_namespace_vue',
  setup(__props, { expose: __expose }) {
  __expose();

const count = vue.ref(0)

const __returned__ = { count, vue }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
