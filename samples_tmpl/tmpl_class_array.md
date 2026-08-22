# tmpl_class_array

```
import { normalizeClass as _normalizeClass, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    class: _normalizeClass([_ctx.a, 'b', { c: _ctx.ok }])
  }, "x", 2 /* CLASS */))
}
```
