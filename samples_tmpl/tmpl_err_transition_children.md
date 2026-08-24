# tmpl_err_transition_children

```
import { createElementVNode as _createElementVNode, Transition as _Transition, withCtx as _withCtx, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createBlock(_Transition, null, {
    default: _withCtx(() => [...(_cache[0] || (_cache[0] = [
      _createElementVNode("div", null, "a", -1 /* CACHED */),
      _createElementVNode("div", null, "b", -1 /* CACHED */)
    ]))]),
    _: 1 /* STABLE */
  }))
}
```
ERRORS: SyntaxError: <Transition> expects exactly one child element or component.
