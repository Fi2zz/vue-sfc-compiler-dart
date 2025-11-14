# effectScope_basic

示例：

```vue
<script setup lang="ts">
import { effectScope } from 'vue'
const scope = effectScope()
scope.stop()
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { effectScope } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'effectScope_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const scope = effectScope()
scope.stop()

const __returned__ = { scope, effectScope }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

