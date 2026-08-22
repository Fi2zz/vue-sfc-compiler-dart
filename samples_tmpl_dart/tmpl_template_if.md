# tmpl_template_if

```
import { createElementVNode as _createElementVNode, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, createCommentVNode as _createCommentVNode } from "vue"

export function render(_ctx, _cache) {
  return (_ctx.ok)
    ? (_openBlock(), _createElementBlock(_Fragment, { key: 0 }, [
        _cache[0] || (_cache[0] = _createElementVNode("p", null, "a", -1 /* CACHED */)),
        _cache[1] || (_cache[1] = _createElementVNode("p", null, "b", -1 /* CACHED */))
      ], 64 /* STABLE_FRAGMENT */))
    : _createCommentVNode("v-if", true)
}
```
