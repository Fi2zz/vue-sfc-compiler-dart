# tmpl_slot_outlet

```
import { renderSlot as _renderSlot, createTextVNode as _createTextVNode } from "vue"

export function render(_ctx, _cache) {
  return _renderSlot(_ctx.$slots, "foo", { bar: _ctx.baz }, () => [
    _cache[0] || (_cache[0] = _createTextVNode("fallback", -1 /* CACHED */))
  ])
}
```
