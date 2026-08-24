# inline_literal_hoist

```
import { toDisplayString as _toDisplayString, unref as _unref, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

const a = 1
const b = 'x'

export default {
  __name: 'inline_literal_hoist',
  setup(__props) {

let c = 2

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("p", null, _toDisplayString(a) + " " + _toDisplayString(b) + " " + _toDisplayString(_unref(c)), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"a":"literal-const","b":"literal-const","c":"setup-let"}
