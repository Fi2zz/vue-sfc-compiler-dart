# tmpl_err_v_slot_outlet_dyn

```
import { renderSlot as _renderSlot, createTextVNode as _createTextVNode } from "vue"

export function render(_ctx, _cache) {
  return _renderSlot(_ctx.$slots, _ctx.n, {}, () => [
    _cache[0] || (_cache[0] = _createTextVNode("x", -1 /* CACHED */))
  ])
}
```
