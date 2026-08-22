# tmpl_dyn_arg_event

```
import { toHandlerKey as _toHandlerKey, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("button", {
    [_toHandlerKey(_ctx.event)]: _cache[0] || (_cache[0] = (...args) => (_ctx.go && _ctx.go(...args)))
  }, "x", 16 /* FULL_PROPS */))
}
```
