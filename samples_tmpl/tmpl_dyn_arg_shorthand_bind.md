# tmpl_dyn_arg_shorthand_bind

```
import { normalizeProps as _normalizeProps, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", _normalizeProps({ [_ctx.key || ""]: _ctx.val }), "x", 16 /* FULL_PROPS */))
}
```
