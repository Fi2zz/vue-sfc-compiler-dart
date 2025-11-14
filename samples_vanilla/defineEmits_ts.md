# defineEmits_ts

示例：

```vue
<script setup lang="ts">
const emit = defineEmits<{ (e:'update', id: number): void; (e:'remove'): void }>()
emit('remove')
emit('update', 1)
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineEmits_ts',
  emits: ["update", "remove"],
  setup(__props, { expose: __expose, emit: __emit }) {
  __expose();

const emit = __emit
emit('remove')
emit('update', 1)

const __returned__ = { emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

