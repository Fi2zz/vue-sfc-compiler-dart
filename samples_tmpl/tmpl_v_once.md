# tmpl_v_once

```
import { setBlockTracking as _setBlockTracking, toDisplayString as _toDisplayString, createTextVNode as _createTextVNode, createElementVNode as _createElementVNode } from "vue"

export function render(_ctx, _cache) {
  return _cache[0] || (
    _setBlockTracking(-1, true),
    (_cache[0] = _createElementVNode("p", null, [
      _createTextVNode(_toDisplayString(_ctx.msg), 1 /* TEXT */)
    ])).cacheIndex = 0,
    _setBlockTracking(1),
    _cache[0]
  )
}
```
