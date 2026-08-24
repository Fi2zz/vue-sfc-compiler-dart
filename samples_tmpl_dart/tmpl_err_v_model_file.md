# tmpl_err_v_model_file

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("input", {
    type: "file",
    "onUpdate:modelValue": _cache[0] || (_cache[0] = $event => ((_ctx.a) = $event))
  }))
}
```
ERRORS: SyntaxError: v-model cannot be used on file inputs since they are read-only. Use a v-on:change listener instead.
