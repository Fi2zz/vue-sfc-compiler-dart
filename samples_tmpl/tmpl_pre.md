# tmpl_pre

```
import { createElementVNode as _createElementVNode, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock(_Fragment, null, [
    _cache[0] || (_cache[0] = _createElementVNode("pre", null, "  keep\n    spaces", -1 /* CACHED */)),
    _cache[1] || (_cache[1] = _createElementVNode("p", { class: "a" }, "x", -1 /* CACHED */))
  ], 64 /* STABLE_FRAGMENT */))
}
```
