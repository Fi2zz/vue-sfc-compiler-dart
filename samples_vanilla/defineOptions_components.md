# defineOptions_components

示例：

```vue
<script setup lang="ts">
defineOptions({ name: 'WithComp', components: { A: {} } })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  ...{ name: 'WithComp', components: { A: {} } },
  __name: 'defineOptions_components',
  setup(__props, { expose: __expose }) {
  __expose();



const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

