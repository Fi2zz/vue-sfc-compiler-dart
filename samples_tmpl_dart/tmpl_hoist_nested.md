# tmpl_hoist_nested

```
import { createElementVNode as _createElementVNode, toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, [
    _cache[0] || (_cache[0] = _createElementVNode("span", { class: "a" }, [
      _createElementVNode("b", null, "static")
    ], -1 /* CACHED */)),
    _createElementVNode("p", null, _toDisplayString(_ctx.dyn), 1 /* TEXT */)
  ]))
}
```
