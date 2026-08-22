# tmpl_bind_component

```
import { openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache, $props, $setup, $data, $options) {
  return (_openBlock(), _createBlock($setup["Foo"], { bar: "1" }))
}
```
