# defineExpose_basic

示例：

```vue
<script setup lang="ts">
function inc(){}
const count = 0
defineExpose({ inc, count })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineExpose_basic',
  setup(__props, { expose: __expose }) {

function inc(){}
const count = 0
__expose({ inc, count })

const __returned__ = { inc, count }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

