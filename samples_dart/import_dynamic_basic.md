# import_dynamic_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({  __name: 'import_dynamic_basic',
setup(__props: any, { expose: __expose }) {
  __expose();
const mod = await import('./nonexistent')
const __returned__ = { mod }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
