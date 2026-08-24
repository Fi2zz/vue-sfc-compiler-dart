# tmpl_err_v_model_arg_plain

```
import { vModelText as _vModelText, withDirectives as _withDirectives, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

const _hoisted_1 = ["title"]

export function render(_ctx, _cache) {
  return _withDirectives((_openBlock(), _createElementBlock("input", {
    title: _ctx.a,
    "onUpdate:title": _cache[0] || (_cache[0] = $event => ((_ctx.a) = $event))
  }, null, 40 /* PROPS, NEED_HYDRATION */, _hoisted_1)), [
    [_vModelText, _ctx.a, "title"]
  ])
}
```
ERRORS: SyntaxError: v-model argument is not supported on plain elements.
