# tmpl_kebab_component

```
import { resolveComponent as _resolveComponent, createVNode as _createVNode, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_my_comp = _resolveComponent("my-comp")
  const _component_MyComp = _resolveComponent("MyComp")

  return (_openBlock(), _createElementBlock(_Fragment, null, [
    _createVNode(_component_my_comp, { foo: "1" }),
    _createVNode(_component_MyComp)
  ], 64 /* STABLE_FRAGMENT */))
}
```
