# script_type_scope_cross_block

```
import { defineComponent as _defineComponent } from 'vue'

export interface CrossBlockProps {
  title: string
  count?: number
  onChange: (v: string) => void
}

export default /*@__PURE__*/_defineComponent({
  __name: 'script_type_scope_cross_block',
  props: {
    title: { type: String, required: true },
    count: { type: Number, required: false },
    onChange: { type: Function, required: true }
  },
  setup(__props: any, { expose: __expose }) {
  __expose();

const props = __props
console.log(props)

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
