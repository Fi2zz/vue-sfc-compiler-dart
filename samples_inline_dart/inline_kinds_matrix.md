# inline_kinds_matrix

```
import { toDisplayString as _toDisplayString, unref as _unref, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

import { ref, computed, reactive } from 'vue'
const lit = 'hi'

export default {
  __name: 'inline_kinds_matrix',
  setup(__props) {

const r = ref(0)
const c = computed(() => r.value * 2)
const s = reactive({ a: 1 })
const m = unknownCall()
let l = 1

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("p", null, _toDisplayString(r.value) + " " + _toDisplayString(c.value) + " " + _toDisplayString(s.a) + " " + _toDisplayString(_unref(m)) + " " + _toDisplayString(_unref(l)) + " " + _toDisplayString(lit), 1 /* TEXT */))
}
}

}
```

BINDINGS: {"ref":"setup-const","computed":"setup-const","reactive":"setup-const","r":"setup-ref","c":"setup-ref","s":"setup-reactive-const","m":"setup-maybe-ref","l":"setup-let","lit":"literal-const"}
