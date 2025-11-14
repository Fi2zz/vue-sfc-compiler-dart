# onUpdated_basic

示例：

```vue
<script setup lang="ts">
import { onUpdated } from 'vue'
onUpdated(() => {})
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { onUpdated } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onUpdated_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onUpdated(() => {})

const __returned__ = { onUpdated }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

