# tmpl_err_v_text_children

```
import { toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

const _hoisted_1 = ["textContent"]

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    textContent: _toDisplayString(_ctx.t)
  }, null, 8 /* PROPS */, _hoisted_1))
}
```
ERRORS: SyntaxError: v-text will override element children.
