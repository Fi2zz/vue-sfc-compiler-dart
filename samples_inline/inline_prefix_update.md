# inline_prefix_update

```
import { toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

import { ref } from "vue"

export default {
  __name: 'inline_prefix_update',
  setup(__props) {

const n = ref(0)

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (++n.value))
  }, _toDisplayString(n.value), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"ref":"setup-const","n":"setup-ref"}
