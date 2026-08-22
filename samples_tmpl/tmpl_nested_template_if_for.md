# tmpl_nested_template_if_for

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString, createCommentVNode as _createCommentVNode } from "vue"

const _hoisted_1 = { key: 0 }

export function render(_ctx, _cache) {
  return (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.groups, (g) => {
    return (_openBlock(), _createElementBlock(_Fragment, {
      key: g.id
    }, [
      (g.show)
        ? (_openBlock(), _createElementBlock("div", _hoisted_1, _toDisplayString(g.name), 1 /* TEXT */))
        : _createCommentVNode("v-if", true)
    ], 64 /* STABLE_FRAGMENT */))
  }), 128 /* KEYED_FRAGMENT */))
}
```
