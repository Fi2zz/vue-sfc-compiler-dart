# defineProps_ts_literal_union_destructure

示例：

```vue
<script setup lang="ts">
const { size = 'medium' } = defineProps<{ size: 'small' | 'medium' | 'large' }>()
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_ts_literal_union_destructure',
  props: {
    size: { type: String, required: true, default: 'medium' }
  },
  setup(__props: any, { expose: __expose }) {
  __expose();



const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

