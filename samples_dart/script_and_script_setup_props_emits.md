# script_and_script_setup_props_emits

```
import { mergeModels as _mergeModels } from 'vue'
{  __name: 'script_and_script_setup_props_emits',
  props: {  },

  emits: ['update', 'delete'],

setup(__props, { expose: __expose, emit: __emit }) {
  __expose();
const props = __props;

const emit = __emit;

const __returned__ = { props, emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}
```
