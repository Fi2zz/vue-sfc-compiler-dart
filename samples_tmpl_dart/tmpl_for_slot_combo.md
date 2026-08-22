# tmpl_for_slot_combo

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString, createElementVNode as _createElementVNode, resolveComponent as _resolveComponent, withCtx as _withCtx, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_List = _resolveComponent("List")

  return (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.rows, (row) => {
    return (_openBlock(), _createBlock(_component_List, {
      key: row.id
    }, {
      default: _withCtx(({ item }) => [
        _createElementVNode("span", null, _toDisplayString(item), 1 /* TEXT */)
      ]),
      _: 1 /* STABLE */
    }))
  }), 128 /* KEYED_FRAGMENT */))
}
```
