# triggerRef_basic

示例：

```vue
<script setup lang="ts">
import { shallowRef, triggerRef } from 'vue'
const r = shallowRef(1)
triggerRef(r)
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { shallowRef, triggerRef } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'triggerRef_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const r = shallowRef(1)
triggerRef(r)

const __returned__ = { r, shallowRef, triggerRef }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

