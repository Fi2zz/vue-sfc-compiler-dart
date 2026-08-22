# tmpl_scoped

```
import { createElementVNode as _createElementVNode, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, [...(_cache[0] || (_cache[0] = [
    _createElementVNode("p", { class: "a" }, "scoped", -1 /* CACHED */)
  ]))]))
}
```
