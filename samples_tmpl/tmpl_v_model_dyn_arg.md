# tmpl_v_model_dyn_arg

```
import { resolveComponent as _resolveComponent, normalizeProps as _normalizeProps, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_my_comp = _resolveComponent("my-comp")

  return (_openBlock(), _createBlock(_component_my_comp, _normalizeProps({
    [_ctx.prop]: _ctx.val,
    ["onUpdate:" + _ctx.prop]: _cache[0] || (_cache[0] = $event => ((_ctx.val) = $event)),
    [_ctx.prop + "Modifiers"]: { trim: true }
  }), null, 16 /* FULL_PROPS */))
}
```
