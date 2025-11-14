# export_type_basic

示例：

```vue
<script setup lang="ts">
export type Result = { ok: boolean }
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
export type Result = { ok: boolean }

export default /*@__PURE__*/_defineComponent({
  __name: 'export_type_basic',
  setup(__props, { expose: __expose }) {
  __expose();


const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

