# tmpl_event_key_mod

```
import { withModifiers as _withModifiers, withKeys as _withKeys, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("input", {
    onKeyup: _cache[0] || (_cache[0] = _withKeys(_withModifiers((...args) => (_ctx.go && _ctx.go(...args)), ["exact"]), ["enter"])),
    onKeydown: _cache[1] || (_cache[1] = _withKeys((...args) => (_ctx.go2 && _ctx.go2(...args)), ["a","b"]))
  }, null, 32 /* NEED_HYDRATION */))
}
```
