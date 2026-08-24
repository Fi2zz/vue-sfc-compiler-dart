# tmpl_err_v_html_children

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

const _hoisted_1 = ["innerHTML"]

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", { innerHTML: _ctx.h }, null, 8 /* PROPS */, _hoisted_1))
}
```
ERRORS: SyntaxError: v-html will override element children.
