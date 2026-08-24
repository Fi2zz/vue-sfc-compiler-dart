# tmpl_err_v_model_invalid_el

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    "onUpdate:modelValue": _cache[0] || (_cache[0] = $event => ((_ctx.x) = $event))
  }))
}
```
ERRORS: SyntaxError: v-model can only be used on <input>, <textarea> and <select> elements.
