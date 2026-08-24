# tmpl_err_v_bind_same_name_dyn

```
import { normalizeProps as _normalizeProps, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", _normalizeProps({ [_ctx.arg]: "" }), null, 16 /* FULL_PROPS */))
}
```
ERRORS: SyntaxError: v-bind with same-name shorthand only allows static argument.; SyntaxError: v-bind is missing expression.
