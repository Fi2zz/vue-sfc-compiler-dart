# onErrorCaptured_basic

示例：

```vue
<script setup lang="ts">
import { onErrorCaptured } from 'vue'
onErrorCaptured(() => false)
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { onErrorCaptured } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onErrorCaptured_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onErrorCaptured(() => false)

const __returned__ = { onErrorCaptured }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

