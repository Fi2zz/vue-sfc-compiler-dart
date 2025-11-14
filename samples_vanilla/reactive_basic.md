# reactive_basic

示例：

```vue
<script setup lang="ts">
import { reactive } from 'vue'
const state = reactive({ count: 0 })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { reactive } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'reactive_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const state = reactive({ count: 0 })

const __returned__ = { state, reactive }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

