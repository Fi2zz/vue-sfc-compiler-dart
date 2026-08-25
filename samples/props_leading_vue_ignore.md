# props_leading_vue_ignore

```
import { defineComponent as _defineComponent } from 'vue'
type Foo = { foo: number }
type Bar = { bar: boolean }

export default /*@__PURE__*/_defineComponent({
  __name: 'props_leading_vue_ignore',
  props: {
    bar: { type: Boolean, required: true }
  },
  setup(__props: any, { expose: __expose }) {
  __expose();



const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
