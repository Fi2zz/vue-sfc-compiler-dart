# define_model_zh_key_getset

```
import { useModel as _useModel } from 'vue'

export default {
  __name: 'define_model_zh_key_getset',
  props: {
    "标题": { },
    "标题Modifiers": {},
  },
  emits: ["update:标题"],
  setup(__props, { expose: __expose }) {
  __expose();

const title = _useModel(__props, "标题", { get: (v) => v, set: (v) => v })

const __returned__ = { title }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```
