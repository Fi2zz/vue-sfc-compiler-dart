# tmpl_v_bind

```
import { normalizeClass as _normalizeClass, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

const _hoisted_1 = ["id"]

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    id: _ctx.foo,
    class: _normalizeClass(_ctx.cls)
  }, "x", 10 /* CLASS, PROPS */, _hoisted_1))
}
```
