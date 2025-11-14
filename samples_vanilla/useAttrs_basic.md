# useAttrs_basic

示例：

```vue
<script setup lang="ts">
const attrs = useAttrs()
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'useAttrs_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const attrs = useAttrs()

const __returned__ = { attrs }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

