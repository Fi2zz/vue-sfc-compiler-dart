# import_basic

示例：

```vue
<script setup lang="ts">
import { ref, isRef } from 'vue'
const a = ref(1)
const ok = isRef(a)
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { ref, isRef } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'import_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const a = ref(1)
const ok = isRef(a)

const __returned__ = { a, ok, ref, isRef }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

