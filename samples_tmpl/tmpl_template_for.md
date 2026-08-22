# tmpl_template_for

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString, createElementVNode as _createElementVNode } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock(_Fragment, null, _renderList(3, (i) => {
    return _createElementVNode("p", { key: i }, _toDisplayString(i), 1 /* TEXT */)
  }), 64 /* STABLE_FRAGMENT */))
}
```
