# tmpl_bind_setup_let

```
import { toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache, $props, $setup, $data, $options) {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => ($setup.count++))
  }, _toDisplayString($setup.count), 1 /* TEXT */))
}
```
