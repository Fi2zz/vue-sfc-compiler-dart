# onBeforeUpdate_basic

示例：

```vue
<script setup lang="ts">
import { onBeforeUpdate } from 'vue'
onBeforeUpdate(() => {})
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { onBeforeUpdate } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onBeforeUpdate_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onBeforeUpdate(() => {})

const __returned__ = { onBeforeUpdate }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

