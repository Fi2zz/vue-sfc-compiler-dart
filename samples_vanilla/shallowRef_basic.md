# shallowRef_basic

示例：

```vue
<script setup lang="ts">
import { shallowRef } from 'vue'
const a = shallowRef(1)
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { shallowRef } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'shallowRef_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const a = shallowRef(1)

const __returned__ = { a, shallowRef }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

