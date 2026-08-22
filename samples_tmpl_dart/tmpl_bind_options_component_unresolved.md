# tmpl_bind_options_component_unresolved

```
import { resolveComponent as _resolveComponent, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache, $props, $setup, $data, $options) {
  const _component_Foo = _resolveComponent("Foo")

  return (_openBlock(), _createBlock(_component_Foo))
}
```
