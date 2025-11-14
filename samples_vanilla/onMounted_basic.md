# onMounted_basic

示例：

```vue
<script setup lang="ts">
import { onMounted } from 'vue'
onMounted(() => {})
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { onMounted } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'onMounted_basic',
  setup(__props, { expose: __expose }) {
  __expose();

onMounted(() => {})

const __returned__ = { onMounted }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

