# onServerPrefetch_basic

示例：

```vue
<script setup lang="ts">
import { onServerPrefetch } from 'vue'
onServerPrefetch(async () => {})
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { onServerPrefetch } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onServerPrefetch_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onServerPrefetch(async () => {})

const __returned__ = { onServerPrefetch }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

