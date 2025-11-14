# watchSyncEffect_basic

示例：

```vue
<script setup lang="ts">
import { ref, watchSyncEffect } from 'vue'
const v = ref(0)
watchSyncEffect(() => { v.value })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref, watchSyncEffect } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'watchSyncEffect_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const v = ref(0)
watchSyncEffect(() => { v.value })

const __returned__ = { v, ref, watchSyncEffect }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

