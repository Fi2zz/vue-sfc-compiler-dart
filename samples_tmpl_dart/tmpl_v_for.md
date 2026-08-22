# tmpl_v_for

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("ul", null, [
    (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.items, (item) => {
      return (_openBlock(), _createElementBlock("li", null, _toDisplayString(item), 1 /* TEXT */))
    }), 256 /* UNKEYED_FRAGMENT */))
  ]))
}
```
