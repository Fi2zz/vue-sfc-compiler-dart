# tmpl_err_vnode_hooks

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", {
    onVnodeMounted: _cache[0] || (_cache[0] = (...args) => (_ctx.fn && _ctx.fn(...args)))
  }, "x", 512 /* NEED_PATCH */))
}
```
ERRORS: SyntaxError: @vnode-* hooks in templates are no longer supported. Use the vue: prefix instead. For example, @vnode-mounted should be changed to @vue:mounted. @vnode-* hooks support has been removed in 3.4.
