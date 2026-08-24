# inline_maybe_ref_assign

```
import { unref as _unref, toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

import { customThing } from './thing'

export default {
  __name: 'inline_maybe_ref_assign',
  setup(__props) {

const m = customThing()

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (m.value = 2))
  }, _toDisplayString(_unref(m)), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"customThing":"setup-maybe-ref","m":"setup-maybe-ref"}
