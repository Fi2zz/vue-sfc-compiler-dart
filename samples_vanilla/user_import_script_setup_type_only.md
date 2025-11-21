# user_import_script_setup_type_only

示例：

```vue
<script setup lang="ts">
import type { Component } from 'vue'
let c: Component | null = null
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import type { Component } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'user_import_script_setup_type_only',
  setup(__props, { expose: __expose }) {
  __expose();

let c: Component | null = null

const __returned__ = { get c() { return c }, set c(v) { c = v } }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

