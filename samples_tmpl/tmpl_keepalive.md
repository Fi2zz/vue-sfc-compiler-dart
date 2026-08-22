# tmpl_keepalive

```
import { resolveDynamicComponent as _resolveDynamicComponent, openBlock as _openBlock, createBlock as _createBlock, KeepAlive as _KeepAlive } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createBlock(_KeepAlive, { include: ['a'] }, [
    (_openBlock(), _createBlock(_resolveDynamicComponent(_ctx.view)))
  ], 1024 /* DYNAMIC_SLOTS */))
}
```
