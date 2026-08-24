# tmpl_err_v_model_scope_var

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, createElementVNode as _createElementVNode } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.list, (i) => {
    return (_openBlock(), _createElementBlock("div", null, [...(_cache[0] || (_cache[0] = [
      _createElementVNode("input", null, null, -1 /* CACHED */)
    ]))]))
  }), 256 /* UNKEYED_FRAGMENT */))
}
```
ERRORS: SyntaxError: v-model cannot be used on v-for or v-slot scope variables because they are not writable.
