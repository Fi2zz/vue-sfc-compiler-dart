# tmpl_static_nested

```
import { createElementVNode as _createElementVNode, createStaticVNode as _createStaticVNode, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, [...(_cache[0] || (_cache[0] = [
    _createStaticVNode("<ul class=\"list\"><li class=\"i\">a</li><li class=\"i\">b</li><li class=\"i\">c</li></ul><p class=\"x\">t</p>", 2)
  ]))]))
}
```
