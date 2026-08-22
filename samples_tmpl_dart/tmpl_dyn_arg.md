# tmpl_dyn_arg

```
import { toHandlerKey as _toHandlerKey, mergeProps as _mergeProps, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", _mergeProps({ [_ctx.attr || ""]: _ctx.val }, {
    [_toHandlerKey(_ctx.event)]: _cache[0] || (_cache[0] = (...args) => (_ctx.handler && _ctx.handler(...args)))
  }), null, 16 /* FULL_PROPS */))
}
```
