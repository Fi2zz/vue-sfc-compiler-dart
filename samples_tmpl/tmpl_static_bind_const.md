# tmpl_static_bind_const

```
import { normalizeClass as _normalizeClass, createElementVNode as _createElementVNode, createStaticVNode as _createStaticVNode, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, [...(_cache[0] || (_cache[0] = [
    _createStaticVNode("<p class=\"a b\">1</p><p style=\"color:red;\">2</p><p title=\"t1\">3</p><p>4</p><p>txt</p>", 5)
  ]))]))
}
```
ERRORS: SyntaxError: v-text will override element children.
