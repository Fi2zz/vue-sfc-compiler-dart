# tmpl_err_v_slot_dup_names

```
import { createTextVNode as _createTextVNode, resolveComponent as _resolveComponent, withCtx as _withCtx, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_my_comp = _resolveComponent("my-comp")

  return (_openBlock(), _createBlock(_component_my_comp, null, {
    a: _withCtx(() => [...(_cache[0] || (_cache[0] = [
      _createTextVNode("1", -1 /* CACHED */)
    ]))]),
    _: 1 /* STABLE */
  }))
}
```
ERRORS: SyntaxError: Duplicate slot names found. 
