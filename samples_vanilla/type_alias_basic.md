# type_alias_basic

示例：

```vue
<script setup lang="ts">
type User = { id: number; name: string }
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
type User = { id: number; name: string }

export default /*@__PURE__*/_defineComponent({
  __name: 'type_alias_basic',
  setup(__props, { expose: __expose }) {
  __expose();


const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

