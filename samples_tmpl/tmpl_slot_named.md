# tmpl_slot_named

```
import { createElementVNode as _createElementVNode, resolveComponent as _resolveComponent, withCtx as _withCtx, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_Layout = _resolveComponent("Layout")

  return (_openBlock(), _createBlock(_component_Layout, null, {
    header: _withCtx(() => [...(_cache[0] || (_cache[0] = [
      _createElementVNode("h1", null, "Title", -1 /* CACHED */)
    ]))]),
    default: _withCtx(() => [
      _cache[1] || (_cache[1] = _createElementVNode("p", null, "body", -1 /* CACHED */))
    ]),
    _: 1 /* STABLE */
  }))
}
```
