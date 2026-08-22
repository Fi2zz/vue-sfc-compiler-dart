# tmpl_v_memo

```
import { toDisplayString as _toDisplayString, createTextVNode as _createTextVNode, openBlock as _openBlock, createElementBlock as _createElementBlock, withMemo as _withMemo } from "vue"

export function render(_ctx, _cache) {
  return _withMemo([_ctx.value], () => (_openBlock(), _createElementBlock("div", null, [
    _createTextVNode(_toDisplayString(_ctx.value), 1 /* TEXT */)
  ])), _cache, 0)
}
```
