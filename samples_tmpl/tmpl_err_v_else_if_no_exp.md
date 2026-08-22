# tmpl_err_v_else_if_no_exp

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock, createCommentVNode as _createCommentVNode } from "vue"

const _hoisted_1 = { key: 0 }
const _hoisted_2 = { key: 1 }

export function render(_ctx, _cache) {
  return (_ctx.a)
    ? (_openBlock(), _createElementBlock("div", _hoisted_1))
    : true
      ? (_openBlock(), _createElementBlock("div", _hoisted_2, "x"))
      : _createCommentVNode("v-if", true)
}
```
ERRORS: SyntaxError: v-if/v-else-if is missing expression.
