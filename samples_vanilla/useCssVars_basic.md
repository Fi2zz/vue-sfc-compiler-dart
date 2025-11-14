# useCssVars_basic

示例：

```vue
<script setup lang="ts">
const color = 'red'
useCssVars(() => ({ color }))
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'useCssVars_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const color = 'red'
useCssVars(() => ({ color }))

const __returned__ = { color }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

