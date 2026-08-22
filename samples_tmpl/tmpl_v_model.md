# tmpl_v_model

```
import { vModelText as _vModelText, withDirectives as _withDirectives, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return _withDirectives((_openBlock(), _createElementBlock("input", {
    "onUpdate:modelValue": _cache[0] || (_cache[0] = $event => ((_ctx.text) = $event))
  }, null, 512 /* NEED_PATCH */)), [
    [_vModelText, _ctx.text]
  ])
}
```
