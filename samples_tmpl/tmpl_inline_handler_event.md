# tmpl_inline_handler_event

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (_ctx.go($event, 1)))
  }, "x"))
}
```
