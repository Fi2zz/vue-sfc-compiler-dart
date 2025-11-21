# withDefaults_non_call_error

```ts
import { defineComponent as _defineComponent } from 'vue'
export default /*@__PURE__*/_defineComponent({  __name: 'withDefaults_non_call_error',
  props: {  },

setup(__props: any, { expose: __expose }) {
  __expose();
const foo = {} as any
const {a} = __props;

const __returned__ = { foo, a }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
