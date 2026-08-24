# inline_props

```
import { defineComponent as _defineComponent } from 'vue'
import { toDisplayString as _toDisplayString, openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

const local = 1

export default /*@__PURE__*/_defineComponent({
  __name: 'inline_props',
  props: {
    title: { type: String, required: true },
    "data-x": { type: Number, required: false }
  },
  setup(__props: any) {



return (_ctx: any,_cache: any) => {
  return (_openBlock(), _createElementBlock("p", null, _toDisplayString(__props.title) + " " + _toDisplayString(local) + " " + _toDisplayString(_ctx.datax), 1 /* TEXT */))
}
}

})
```

BINDINGS: {"local":"literal-const","title":"props","data-x":"props"}
