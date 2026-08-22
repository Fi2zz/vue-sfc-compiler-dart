# tmpl_v_for_nested_slot

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString, createElementVNode as _createElementVNode, resolveComponent as _resolveComponent, withCtx as _withCtx, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_my_comp = _resolveComponent("my-comp")

  return (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.list, (it) => {
    return (_openBlock(), _createBlock(_component_my_comp, {
      key: it.id
    }, {
      default: _withCtx(({ row }) => [
        _createElementVNode("span", null, _toDisplayString(row.name), 1 /* TEXT */)
      ]),
      _: 1 /* STABLE */
    }))
  }), 128 /* KEYED_FRAGMENT */))
}
```
