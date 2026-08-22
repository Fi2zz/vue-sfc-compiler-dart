# tmpl_suspense

```
import { resolveComponent as _resolveComponent, createVNode as _createVNode, createTextVNode as _createTextVNode, Suspense as _Suspense, withCtx as _withCtx, openBlock as _openBlock, createBlock as _createBlock } from "vue"

export function render(_ctx, _cache) {
  const _component_AsyncComp = _resolveComponent("AsyncComp")

  return (_openBlock(), _createBlock(_Suspense, null, {
    default: _withCtx(() => [
      _createVNode(_component_AsyncComp)
    ]),
    fallback: _withCtx(() => [...(_cache[0] || (_cache[0] = [
      _createTextVNode("loading", -1 /* CACHED */)
    ]))]),
    _: 1 /* STABLE */
  }))
}
```
