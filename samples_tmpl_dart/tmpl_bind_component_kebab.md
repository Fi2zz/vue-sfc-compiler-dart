# tmpl_bind_component_kebab

```
import { createVNode as _createVNode, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache, $props, $setup, $data, $options) {
  return (_openBlock(), _createElementBlock(_Fragment, null, [
    _createVNode($setup["FooBar"]),
    _createVNode($setup["FooBar"])
  ], 64 /* STABLE_FRAGMENT */))
}
```
