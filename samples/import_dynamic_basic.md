# import_dynamic_basic

```
import { withAsyncContext as _withAsyncContext, defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'import_dynamic_basic',
  async setup(__props, { expose: __expose }) {
  __expose();

let __temp: any, __restore: any

const mod = (
  ([__temp,__restore] = _withAsyncContext(() => import('./nonexistent'))),
  __temp = await __temp,
  __restore(),
  __temp
)

const __returned__ = { mod }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

