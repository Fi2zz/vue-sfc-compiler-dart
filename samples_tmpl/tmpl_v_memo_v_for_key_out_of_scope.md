# tmpl_v_memo_v_for_key_out_of_scope

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString, createTextVNode as _createTextVNode, withMemo as _withMemo } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, [
    (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.list, (i) => {
      return _withMemo([i], () => (_openBlock(), _createElementBlock("span", null, [
        _createTextVNode(_toDisplayString(i), 1 /* TEXT */)
      ])), _cache, 0, undefined, _ctx.outer)
    }), 128 /* KEYED_FRAGMENT */))
  ]))
}
```
