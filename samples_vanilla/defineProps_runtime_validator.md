# defineProps_runtime_validator

示例：

```vue
<script setup lang="ts">
const props = defineProps({ count: { type: Number, validator: (v:number)=> v >= 0 } })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineProps_runtime_validator',
  props: { count: { type: Number, validator: (v:number)=> v >= 0 } },
  setup(__props, { expose: __expose }) {
  __expose();

const props = __props

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

