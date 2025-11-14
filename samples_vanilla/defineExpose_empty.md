# defineExpose_empty

示例：

```vue
<script setup lang="ts">
defineExpose()
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineExpose_empty',
  setup(__props, { expose: __expose }) {

__expose()

const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

