# interface_basic

示例：

```vue
<script setup lang="ts">
interface Point { x: number; y: number }
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
interface Point { x: number; y: number }

export default /*@__PURE__*/_defineComponent({
  __name: 'interface_basic',
  setup(__props, { expose: __expose }) {
  __expose();


const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

