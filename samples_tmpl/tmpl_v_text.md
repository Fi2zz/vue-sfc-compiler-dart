# tmpl_v_text

```
import { toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

const _hoisted_1 = ["textContent"]

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    textContent: _toDisplayString(_ctx.txt)
  }, null, 8 /* PROPS */, _hoisted_1))
}
```
