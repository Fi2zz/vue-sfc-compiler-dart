# as_const_basic

示例：

```vue
<script setup lang="ts">
const cfg = { a: 1 } as const
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'as_const_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const cfg = { a: 1 } as const

const __returned__ = { cfg }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

