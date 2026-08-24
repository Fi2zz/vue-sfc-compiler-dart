# inline_ts

```
import { defineComponent as _defineComponent } from 'vue'
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

const _hoisted_1 = ["value"]

import { ref } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'inline_ts',
  setup(__props) {

const n = ref(0)

return (_ctx: any,_cache: any) => {
  return (_openBlock(), _createElementBlock("input", {
    value: n.value,
    onChange: _cache[0] || (_cache[0] = ($event: any) => (n.value = Number($event)))
  }, null, 40 /* PROPS, NEED_HYDRATION */, _hoisted_1))
}
}

})
```

BINDINGS: {"ref":"setup-const","n":"setup-ref"}
