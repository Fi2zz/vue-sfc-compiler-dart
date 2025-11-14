# defineOptions_extends

示例：

```vue
<script setup lang="ts">
defineOptions({ name: 'Extended', extends: { props: { a: String } } })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  ...{ name: 'Extended', extends: { props: { a: String } } },
  __name: 'defineOptions_extends',
  setup(__props, { expose: __expose }) {
  __expose();



const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

