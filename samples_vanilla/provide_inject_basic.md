# provide_inject_basic

示例：

```vue
<script setup lang="ts">
import { provide, inject } from 'vue'
provide('key', 1)
const injected = inject('key', 0)
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { provide, inject } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'provide_inject_basic',
  setup(__props, { expose: __expose }) {
  __expose();

provide('key', 1)
const injected = inject('key', 0)

const __returned__ = { injected, provide, inject }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

