# script_and_script_setup_mixed_features

```
import { ref, computed } from "vue";export default /*@__PURE__*/_defineComponent({
  __name: 'script_and_script_setup_mixed_features',
setup(__props, { expose: __expose }) {
  __expose();

const setupCount = ref(0)
const setupComputed = computed(() => setupCount.value * 2)

const __returned__ = { setupCount, setupComputed }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
