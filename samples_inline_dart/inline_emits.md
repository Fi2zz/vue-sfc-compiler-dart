# inline_emits

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"


export default {
  __name: 'inline_emits',
  emits: ['go'],
  setup(__props, { emit: __emit }) {

const emit = __emit

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = $event => (emit('go')))
  }, "go"))
}
}

}
```

BINDINGS: {"emit":"setup-const"}
