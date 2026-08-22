# tmpl_v_for_destructure

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.list, ({ a, b }, i) => {
    return (_openBlock(), _createElementBlock("div", { key: i }, _toDisplayString(a) + _toDisplayString(b), 1 /* TEXT */))
  }), 128 /* KEYED_FRAGMENT */))
}
```
