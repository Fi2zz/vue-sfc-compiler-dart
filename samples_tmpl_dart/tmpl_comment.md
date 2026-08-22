# tmpl_comment

```
import { createCommentVNode as _createCommentVNode, createElementVNode as _createElementVNode, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock(_Fragment, null, [
    _createCommentVNode(" hi "),
    _createElementVNode("div", null, "x")
  ], 2112 /* STABLE_FRAGMENT, DEV_ROOT_FRAGMENT */))
}
```
