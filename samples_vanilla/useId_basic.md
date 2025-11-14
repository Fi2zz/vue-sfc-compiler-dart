# useId_basic

示例：

```vue
<script setup lang="ts">
const uid = useId()
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'useId_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const uid = useId()

const __returned__ = { uid }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

