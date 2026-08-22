# tmpl_bind_options_computed

```
import { toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache, $props, $setup, $data, $options) {
  return (_openBlock(), _createElementBlock("div", {
    onClick: _cache[0] || (_cache[0] = (...args) => ($options.go && $options.go(...args)))
  }, _toDisplayString($options.doubled), 1 /* TEXT */))
}
```
