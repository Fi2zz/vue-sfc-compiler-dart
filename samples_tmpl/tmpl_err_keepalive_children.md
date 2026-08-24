# tmpl_err_keepalive_children

```
import { createElementVNode as _createElementVNode, KeepAlive as _KeepAlive, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createBlock(_KeepAlive, null, [
    _cache[0] || (_cache[0] = _createElementVNode("div", null, "a", -1 /* CACHED */)),
    _cache[1] || (_cache[1] = _createElementVNode("div", null, "b", -1 /* CACHED */))
  ], 1024 /* DYNAMIC_SLOTS */))
}
```
ERRORS: SyntaxError: <KeepAlive> expects exactly one child component.
