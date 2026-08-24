# tmpl_err_v_if_same_key

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock, createCommentVNode as _createCommentVNode } from "vue"

const _hoisted_1 = { key: "x" }
const _hoisted_2 = { key: "x" }

export function render(_ctx, _cache) {
  return (_ctx.a)
    ? (_openBlock(), _createElementBlock("div", _hoisted_1))
    : (_ctx.b)
      ? (_openBlock(), _createElementBlock("div", _hoisted_2))
      : _createCommentVNode("v-if", true)
}
```
ERRORS: SyntaxError: v-if/else branches must use unique keys.
