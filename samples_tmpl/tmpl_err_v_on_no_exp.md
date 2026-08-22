# tmpl_err_v_on_no_exp

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    onClick: _cache[0] || (_cache[0] = () => {})
  }))
}
```
ERRORS: SyntaxError: v-on is missing expression.
