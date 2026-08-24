# tmpl_err_v_for_malformed

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, "x"))
}
```
ERRORS: SyntaxError: v-for has invalid expression.
