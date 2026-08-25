# define_model_template_name

```
import { useModel as _useModel } from 'vue'

export default {
  __name: 'define_model_template_name',
  props: {
    "foo": {},
    "fooModifiers": {},
  },
  emits: ["update:foo"],
  setup(__props, { expose: __expose }) {
  __expose();

const m = _useModel(__props, `foo`)

const __returned__ = { m }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```
