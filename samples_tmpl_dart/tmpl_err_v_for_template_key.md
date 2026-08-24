# tmpl_err_v_for_template_key

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(_ctx.list, (i) => {
    return (_openBlock(), _createElementBlock("span", { key: i }, _toDisplayString(i), 1 /* TEXT */))
  }), 256 /* UNKEYED_FRAGMENT */))
}
```
ERRORS: SyntaxError: <template v-for> key should be placed on the <template> tag.
