# tmpl_event_modifiers

```
import { withModifiers as _withModifiers, withKeys as _withKeys, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = _withModifiers((...args) => (_ctx.go && _ctx.go(...args)), ["stop","prevent"])),
    onKeyup: _cache[1] || (_cache[1] = _withKeys((...args) => (_ctx.submit && _ctx.submit(...args)), ["enter"]))
  }, "go", 32 /* NEED_HYDRATION */))
}
```
