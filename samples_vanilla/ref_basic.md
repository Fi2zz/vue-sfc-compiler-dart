# ref_basic

示例：

```vue
<script setup lang="ts">
import { ref } from 'vue'
const count = ref(0)
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'ref_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const count = ref(0)

const __returned__ = { count, ref }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

