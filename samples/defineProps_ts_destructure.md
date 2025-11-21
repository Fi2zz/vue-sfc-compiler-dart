# defineProps_ts_destructure

```
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_ts_destructure',
  props: {
    msg: { type: String, required: true, default: 'hi' },
    count: { type: Number, required: false, default: 1 }
  },
  setup(__props: any, { expose: __expose }) {
  __expose();



const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

