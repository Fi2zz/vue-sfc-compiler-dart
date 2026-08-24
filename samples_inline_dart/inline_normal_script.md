# inline_normal_script

```
import { defineComponent as _defineComponent } from 'vue'
import { toDisplayString as _toDisplayString, unref as _unref, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

import { useStore } from './store'

export interface P { a: string }
export const k = 5

export default /*@__PURE__*/_defineComponent({
  __name: 'inline_normal_script',
  props: {
    a: { type: String, required: true }
  },
  setup(__props: any) {


const st = useStore()

return (_ctx: any,_cache: any) => {
  return (_openBlock(), _createElementBlock("p", null, _toDisplayString(__props.a) + " " + _toDisplayString(_unref(st).something) + " " + _toDisplayString(_ctx.k2), 1 /* TEXT */))
}
}

})
```

BINDINGS: {"useStore":"setup-maybe-ref","k":"literal-const","st":"setup-maybe-ref","a":"props"}
