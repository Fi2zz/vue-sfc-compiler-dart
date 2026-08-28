# inline_destructure_array_assign

```
import { unref as _unref, toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"


export default {
  __name: 'inline_destructure_array_assign',
  setup(__props) {

let a

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => ([a] = [1]))
  }, _toDisplayString(_unref(a)), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"a":"setup-let"}
