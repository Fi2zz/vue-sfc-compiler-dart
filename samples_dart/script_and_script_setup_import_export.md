# script_and_script_setup_import_export

```
import { ref } from "vue";import { anotherUtil } from "./another-utils";import { someUtil } from "./utils";
export default /*@__PURE__*/_defineComponent({
  __name: 'script_and_script_setup_import_export',
setup(__props, { expose: __expose }) {
  __expose();

const localValue = ref('local')

const __returned__ = { localValue }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
