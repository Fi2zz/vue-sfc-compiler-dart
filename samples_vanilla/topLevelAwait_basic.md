# topLevelAwait_basic

示例：

```vue
<script setup>
const res = await Promise.resolve(1)
</script>
```

编译输出：

```ts
import { withAsyncContext as _withAsyncContext } from 'vue'

export default {
  __name: 'topLevelAwait_basic',
  async setup(__props, { expose: __expose }) {
  __expose();

let __temp, __restore

const res = (
  ([__temp,__restore] = _withAsyncContext(() => Promise.resolve(1))),
  __temp = await __temp,
  __restore(),
  __temp
)

const __returned__ = { res }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

