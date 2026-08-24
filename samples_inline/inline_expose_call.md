# inline_expose_call

```
import { toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

import { ref } from 'vue'

export default {
  __name: 'inline_expose_call',
  setup(__props, { expose: __expose }) {

const x = ref(1)
__expose({ x })

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("i", null, _toDisplayString(x.value), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"ref":"setup-const","x":"setup-ref"}
