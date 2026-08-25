# v_on_vue_prefix

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.list, (i) => {
    return (_openBlock(), _createElementBlock("div", {
      key: i,
      onVnodeBeforeMount: _cache[0] || (_cache[0] = $event => (_ctx.fn())),
      onVnodeUpdate: _cache[1] || (_cache[1] = (...args) => (_ctx.onUpd && _ctx.onUpd(...args)))
    }, _toDisplayString(i), 33 /* TEXT, NEED_HYDRATION */))
  }), 128 /* KEYED_FRAGMENT */))
}
```
