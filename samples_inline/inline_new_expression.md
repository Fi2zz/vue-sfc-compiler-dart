# inline_new_expression

```
import { toDisplayString as _toDisplayString, unref as _unref, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

import { C } from "./c"

export default {
  __name: 'inline_new_expression',
  setup(__props) {


return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (new (_unref(C))()))
  }, _toDisplayString(_ctx.x), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"C":"setup-maybe-ref"}
