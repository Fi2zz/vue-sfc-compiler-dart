# tmpl_component

```
import { resolveComponent as _resolveComponent, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_MyComp = _resolveComponent("MyComp")

  return (_openBlock(), _createBlock(_component_MyComp, {
    prop: _ctx.val,
    onEvent: _ctx.handler
  }, null, 8 /* PROPS */, ["prop", "onEvent"]))
}
```
