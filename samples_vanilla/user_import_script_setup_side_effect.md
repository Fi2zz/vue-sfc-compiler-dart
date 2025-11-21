# user_import_script_setup_side_effect

示例：

```vue
<script setup lang="ts">
import 'reflect-metadata'
const ok = true
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import 'reflect-metadata'

export default /*@__PURE__*/_defineComponent({
  __name: 'user_import_script_setup_side_effect',
  setup(__props, { expose: __expose }) {
  __expose();

const ok = true

const __returned__ = { ok }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

