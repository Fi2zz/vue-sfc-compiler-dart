# nextTick_basic

```
import { withAsyncContext as _withAsyncContext, defineComponent as _defineComponent } from 'vue'
import { nextTick } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'nextTick_basic',
  async setup(__props, { expose: __expose }) {
  __expose();

let __temp: any, __restore: any

;(
  ([__temp,__restore] = _withAsyncContext(() => nextTick())),
  await __temp,
  __restore()
)

const __returned__ = { nextTick }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
