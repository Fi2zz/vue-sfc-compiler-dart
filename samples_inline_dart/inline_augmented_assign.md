# inline_augmented_assign

```
import { toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

import { ref } from "vue"

export default {
  __name: 'inline_augmented_assign',
  setup(__props) {

const n = ref(0)

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (n.value += 2))
  }, _toDisplayString(n.value), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"ref":"setup-const","n":"setup-ref"}
