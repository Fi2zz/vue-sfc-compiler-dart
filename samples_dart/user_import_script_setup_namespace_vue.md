# user_import_script_setup_namespace_vue

```ts
import { defineComponent as _defineComponent } from 'vue'
import * as vue from "vue";export default /*@__PURE__*/_defineComponent({
  __name: 'user_import_script_setup_namespace_vue',
setup(__props: any, { expose: __expose }) {
  __expose();

const count = vue.ref(0)

const __returned__ = { count }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
