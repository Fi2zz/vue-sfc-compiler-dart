# defineEmits_object_validator

```
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineEmits_object_validator',
  emits: { submit(payload: { id: number }) { return true } },
  setup(__props, { expose: __expose, emit: __emit }) {
  __expose();

const emit = __emit
emit('submit', { id: 1 })

const __returned__ = { emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

