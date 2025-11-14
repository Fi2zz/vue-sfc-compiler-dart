# defineModel_required

示例：

```vue
<script setup lang="ts">
const visible = defineModel<boolean>('visible', { required: true })
</script>
```

编译输出：

```ts
import { useModel as _useModel, defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'defineModel_required',
  props: {
    "visible": { type: Boolean, ...{ required: true } },
    "visibleModifiers": {},
  },
  emits: ["update:visible"],
  setup(__props, { expose: __expose }) {
  __expose();

const visible = _useModel<boolean>(__props, 'visible')

const __returned__ = { visible }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

