# inline_destructure_key_assign

```
import { unref as _unref, toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"


export default {
  __name: 'inline_destructure_key_assign',
  setup(__props) {

let x, y

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (({ x: y } = { x: 1 })))
  }, _toDisplayString(_unref(y)), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"x":"setup-let","y":"setup-let"}
