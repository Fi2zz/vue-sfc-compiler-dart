# inline_destructure_default_assign

```
import { unref as _unref, toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"


export default {
  __name: 'inline_destructure_default_assign',
  setup(__props) {

let a, b

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (({ _unref(a) = _unref(b) } = {})))
  }, _toDisplayString(_unref(a)), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"a":"setup-let","b":"setup-let"}
