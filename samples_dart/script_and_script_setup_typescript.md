# script_and_script_setup_typescript

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref } from 'vue';
import type { PropType } from "vue";
export default /*@__PURE__*/_defineComponent({  __name: 'script_and_script_setup_typescript',
  props: { 
    user: { type: Object, required: true }
   },

setup(__props: any, { expose: __expose }) {
  __expose();
const props = __props;

const localCount = ref(0)
const __returned__ = { props, localCount }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
