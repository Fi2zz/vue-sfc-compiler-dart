# script_and_script_setup_typescript

```
import { defineComponent as _defineComponent } from 'vue'
import { ref } from 'vue'


import type { PropType } from 'vue'

interface User {
  id: number
  name: string
}

const __default__ = {
  name: 'UserComponent',
  props: {
    user: {
      type: Object as PropType<User>,
      required: true
    }
  }
}

export default /*@__PURE__*/_defineComponent({
  ...__default__,
  props: {
    user: { type: Object, required: true }
  },
  setup(__props: any, { expose: __expose }) {
  __expose();

const props = __props

const localCount = ref(0)

const __returned__ = { props, localCount, ref }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
