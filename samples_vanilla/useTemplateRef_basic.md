# useTemplateRef_basic

示例：

```vue
<script setup lang="ts">
const input = useTemplateRef('input')
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'useTemplateRef_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const input = useTemplateRef('input')

const __returned__ = { input }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

