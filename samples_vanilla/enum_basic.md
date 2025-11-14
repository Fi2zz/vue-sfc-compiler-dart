# enum_basic

示例：

```vue
<script setup lang="ts">
enum Color { Red, Green }
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'enum_basic',
  setup(__props, { expose: __expose }) {
  __expose();

enum Color { Red, Green }

const __returned__ = { Color }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

