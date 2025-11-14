# import_dynamic_basic

示例：

```vue
<script setup lang="ts">
const mod = await import('./nonexistent')
</script>
```

编译输出：

```ts
import { withAsyncContext as _withAsyncContext, defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'import_dynamic_basic',
  async setup(__props, { expose: __expose }) {
  __expose();

let __temp: any, __restore: any

const mod = (
  ([__temp,__restore] = _withAsyncContext(() => import('./nonexistent'))),
  __temp = await __temp,
  __restore(),
  __temp
)

const __returned__ = { mod }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

