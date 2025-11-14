# watch_basic

示例：

```vue
<script setup lang="ts">
import { ref, watch } from 'vue'
const v = ref(0)
watch(v, (nv, ov) => {})
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref, watch } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'watch_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const v = ref(0)
watch(v, (nv, ov) => {})

const __returned__ = { v, ref, watch }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

