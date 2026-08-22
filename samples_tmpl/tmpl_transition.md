# tmpl_transition

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock, createCommentVNode as _createCommentVNode, Transition as _Transition, withCtx as _withCtx, createBlock as _createBlock } from "vue"

const _hoisted_1 = { key: 0 }

export function render(_ctx, _cache) {
  return (_openBlock(), _createBlock(_Transition, { name: "fade" }, {
    default: _withCtx(() => [
      (_ctx.ok)
        ? (_openBlock(), _createElementBlock("p", _hoisted_1, "hi"))
        : _createCommentVNode("v-if", true)
    ]),
    _: 1 /* STABLE */
  }))
}
```
