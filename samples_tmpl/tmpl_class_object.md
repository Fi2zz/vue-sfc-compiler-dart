# tmpl_class_object

```
import { normalizeClass as _normalizeClass, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    class: _normalizeClass(["base", { active: _ctx.on }])
  }, "x", 2 /* CLASS */))
}
```
