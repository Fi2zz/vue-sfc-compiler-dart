# user_import_script_setup_default_import

```
import { defineComponent as _defineComponent } from 'vue'
import dayjs from 'dayjs'

export default /*@__PURE__*/_defineComponent({
  __name: 'user_import_script_setup_default_import',
  setup(__props, { expose: __expose }) {
  __expose();

const now = dayjs()

const __returned__ = { now, get dayjs() { return dayjs } }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
