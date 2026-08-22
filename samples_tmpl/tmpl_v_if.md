# tmpl_v_if

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock, createCommentVNode as _createCommentVNode } from "vue"

const _hoisted_1 = { key: 0 }
const _hoisted_2 = { key: 1 }

export function render(_ctx, _cache) {
  return (_ctx.ok)
    ? (_openBlock(), _createElementBlock("div", _hoisted_1, "yes"))
    : (_openBlock(), _createElementBlock("div", _hoisted_2, "no"))
}
```
