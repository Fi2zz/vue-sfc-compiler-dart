# useSlots_basic

示例：

```vue
<script setup lang="ts">
const slots = useSlots()
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'useSlots_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const slots = useSlots()

const __returned__ = { slots }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

