# tmpl_style_binding

```
import { normalizeStyle as _normalizeStyle, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    style: _normalizeStyle({ color: _ctx.c, fontSize: _ctx.n + 'px' })
  }, "x", 4 /* STYLE */))
}
```
