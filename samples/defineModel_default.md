# defineModel_default

```
import { useModel as _useModel, defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_default',
  props: {
    "modelValue": { type: String },
    "modelModifiers": {},
  },
  emits: ["update:modelValue"],
  setup(__props, { expose: __expose }) {
  __expose();

const model = _useModel<string>(__props, "modelValue")

const __returned__ = { model }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
