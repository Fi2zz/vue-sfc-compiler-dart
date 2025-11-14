# intersection_types_basic

示例：

```vue
<script setup lang="ts">
type A = { a: number }
type B = { b: string }
type C = A & B
const c: C = { a: 1, b: 'x' }
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'
type A = { a: number }
type B = { b: string }
type C = A & B

export default /*@__PURE__*/_defineComponent({
  __name: 'intersection_types_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const c: C = { a: 1, b: 'x' }

const __returned__ = { c }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

