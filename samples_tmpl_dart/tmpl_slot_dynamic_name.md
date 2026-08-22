# tmpl_slot_dynamic_name

```
import { createTextVNode as _createTextVNode, resolveComponent as _resolveComponent, withCtx as _withCtx, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_Layout = _resolveComponent("Layout")

  return (_openBlock(), _createBlock(_component_Layout, null, {
    [_ctx.name]: _withCtx(() => [...(_cache[0] || (_cache[0] = [
      _createTextVNode("dyn", -1 /* CACHED */)
    ]))]),
    _: 2 /* DYNAMIC */
  }, 1024 /* DYNAMIC_SLOTS */))
}
```
