# tmpl_v_model_component

```
import { resolveComponent as _resolveComponent, createVNode as _createVNode, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_Comp = _resolveComponent("Comp")

  return (_openBlock(), _createElementBlock(_Fragment, null, [
    _createVNode(_component_Comp, {
      modelValue: _ctx.val,
      "onUpdate:modelValue": _cache[0] || (_cache[0] = $event => ((_ctx.val) = $event))
    }, null, 8 /* PROPS */, ["modelValue"]),
    _createVNode(_component_Comp, {
      title: _ctx.t,
      "onUpdate:title": _cache[1] || (_cache[1] = $event => ((_ctx.t) = $event))
    }, null, 8 /* PROPS */, ["title"])
  ], 64 /* STABLE_FRAGMENT */))
}
```
