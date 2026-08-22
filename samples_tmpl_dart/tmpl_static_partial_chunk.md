# tmpl_static_partial_chunk

```
import { createElementVNode as _createElementVNode, toDisplayString as _toDisplayString, createStaticVNode as _createStaticVNode, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, [
    _cache[0] || (_cache[0] = _createStaticVNode("<p class=\"a\">1</p><p class=\"b\">2</p><p class=\"c\">3</p><p class=\"d\">4</p><p class=\"e\">5</p>", 5)),
    _createElementVNode("span", null, _toDisplayString(_ctx.dynamic), 1 /* TEXT */)
  ]))
}
```
