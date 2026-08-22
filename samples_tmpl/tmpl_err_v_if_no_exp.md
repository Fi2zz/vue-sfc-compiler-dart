# tmpl_err_v_if_no_exp

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock, createCommentVNode as _createCommentVNode } from "vue"

const _hoisted_1 = { key: 0 }

export function render(_ctx, _cache) {
  return true
    ? (_openBlock(), _createElementBlock("div", _hoisted_1))
    : _createCommentVNode("v-if", true)
}
```
ERRORS: SyntaxError: v-if/v-else-if is missing expression.
