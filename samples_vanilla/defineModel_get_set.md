# defineModel_get_set

示例：

```vue
<script setup lang="ts">
const value = defineModel<number>('value', { get: (v)=> v, set: (v)=> Math.max(0, v) })
</script>
```

编译输出：

```ts
import { useModel as _useModel, defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_get_set',
  props: {
    "value": { type: Number, ...{ } },
    "valueModifiers": {},
  },
  emits: ["update:value"],
  setup(__props, { expose: __expose }) {
  __expose();

const value = _useModel<number>(__props, 'value', { get: (v)=> v, set: (v)=> Math.max(0, v) })

const __returned__ = { value }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

