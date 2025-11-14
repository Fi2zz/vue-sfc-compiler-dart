# onRenderTracked_basic

示例：

```vue
<script setup lang="ts">
import { onRenderTracked } from 'vue'
onRenderTracked(() => {})
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { onRenderTracked } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onRenderTracked_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onRenderTracked(() => {})

const __returned__ = { onRenderTracked }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

