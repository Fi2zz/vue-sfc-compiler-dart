# tmpl_optional_chain_handler

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (_ctx.a?.b()))
  }, "x"))
}
```
