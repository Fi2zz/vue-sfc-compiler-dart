# getCurrentInstance_emit_basic

示例：

```vue
<script setup lang="ts">
import { getCurrentInstance } from 'vue'
const inst = getCurrentInstance()
inst?.emit?.('change')
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { getCurrentInstance } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'getCurrentInstance_emit_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const inst = getCurrentInstance()
inst?.emit?.('change')

const __returned__ = { inst, getCurrentInstance }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

