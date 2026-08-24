# script_css_vars_inject

```
import { useCssVars as _useCssVars, unref as _unref } from 'vue'
import { ref } from 'vue'

export default {
  __name: 'script_css_vars_inject',
  setup(__props, { expose: __expose }) {
  __expose();

_useCssVars(_ctx => ({
  "./script_css_vars_inject.vue-color": (color.value)
}))

const color = ref('red')

const __returned__ = { color, ref }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```
