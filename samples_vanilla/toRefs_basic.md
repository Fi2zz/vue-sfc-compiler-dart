# toRefs_basic

示例：

```vue
<script setup lang="ts">
import { reactive, toRefs } from 'vue'
const s = reactive({ a: 1, b: 2 })
const { a, b } = toRefs(s)
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
import { reactive, toRefs } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'toRefs_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const s = reactive({ a: 1, b: 2 })
const { a, b } = toRefs(s)

const __returned__ = { s, a, b, reactive, toRefs }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

