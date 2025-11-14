# defineAsyncComponent_basic

示例：

```vue
<script setup lang="ts">
import { defineAsyncComponent } from 'vue'
const Comp = defineAsyncComponent(() => Promise.resolve({}))
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { defineAsyncComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineAsyncComponent_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const Comp = defineAsyncComponent(() => Promise.resolve({}))

const __returned__ = { Comp, defineAsyncComponent }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

