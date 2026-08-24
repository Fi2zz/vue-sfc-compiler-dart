# inline_setup_let_assign

```
import { unref as _unref, toDisplayString as _toDisplayString, isRef as _isRef, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"


export default {
  __name: 'inline_setup_let_assign',
  setup(__props) {

let n = 0

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (_isRef(n) ? n.value = _unref(n) + 1 : n = _unref(n) + 1))
  }, _toDisplayString(_unref(n)), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"n":"setup-let"}
