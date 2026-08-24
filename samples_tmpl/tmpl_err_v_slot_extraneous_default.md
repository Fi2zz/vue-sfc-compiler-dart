# tmpl_err_v_slot_extraneous_default

```
import { createTextVNode as _createTextVNode, createElementVNode as _createElementVNode, resolveComponent as _resolveComponent, withCtx as _withCtx, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_my_comp = _resolveComponent("my-comp")

  return (_openBlock(), _createBlock(_component_my_comp, null, {
    default: _withCtx(() => [...(_cache[0] || (_cache[0] = [
      _createTextVNode("d", -1 /* CACHED */)
    ]))]),
    _: 1 /* STABLE */
  }))
}
```
ERRORS: SyntaxError: Extraneous children found when component already has explicitly named default slot. These children will be ignored.
