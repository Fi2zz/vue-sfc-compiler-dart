# watchPostEffect_basic

示例：

```vue
<script setup lang="ts">
import { ref, watchPostEffect } from 'vue'
const v = ref(0)
watchPostEffect(() => { v.value })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref, watchPostEffect } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'watchPostEffect_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const v = ref(0)
watchPostEffect(() => { v.value })

const __returned__ = { v, ref, watchPostEffect }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

