# conditional_types_basic

```
import { defineComponent as _defineComponent } from 'vue'
type IsString<T> = T extends string ? true : false

export default /*@__PURE__*/_defineComponent({
  __name: 'conditional_types_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const r: IsString<'a'> = true

const __returned__ = { r }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

