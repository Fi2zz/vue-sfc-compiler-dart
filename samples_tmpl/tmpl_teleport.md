# tmpl_teleport

```
import { createElementVNode as _createElementVNode, Teleport as _Teleport, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createBlock(_Teleport, { to: "body" }, [
    _cache[0] || (_cache[0] = _createElementVNode("p", null, "teleported", -1 /* CACHED */))
  ]))
}
```
