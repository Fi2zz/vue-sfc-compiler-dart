# tmpl_slot_scoped

```
import { toDisplayString as _toDisplayString, createElementVNode as _createElementVNode, resolveComponent as _resolveComponent, withCtx as _withCtx, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_List = _resolveComponent("List")

  return (_openBlock(), _createBlock(_component_List, null, {
    default: _withCtx(({ item, index }) => [
      _createElementVNode("span", null, _toDisplayString(index) + " - " + _toDisplayString(item), 1 /* TEXT */)
    ]),
    _: 1 /* STABLE */
  }))
}
```
