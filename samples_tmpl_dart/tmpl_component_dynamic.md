# tmpl_component_dynamic

```
import { resolveDynamicComponent as _resolveDynamicComponent, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createBlock(_resolveDynamicComponent(_ctx.currentView), { foo: 1 }))
}
```
