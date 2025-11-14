# withDefaults_typed_destructure

示例：

```vue
<script setup lang="ts">
const { msg, count } = withDefaults(defineProps<{ msg?: string; count?: number }>(), { msg: 'hi', count: 1 })
</script>
```

编译输出：

```ts
import { defineComponent as _defineComponent } from 'vue'

export default /*@__PURE__*/_defineComponent({
  __name: 'withDefaults_typed_destructure',
  props: {
    msg: { type: String, required: false, default: 'hi' },
    count: { type: Number, required: false, default: 1 }
  },
  setup(__props: any, { expose: __expose }) {
  __expose();

const { msg, count } = __props

const __returned__ = { msg, count }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

警告：

- [@vue/compiler-sfc] withDefaults() is unnecessary when using destructure with defineProps().
Reactive destructure will be disabled when using withDefaults().
Prefer using destructure default values, e.g. const { foo = 1 } = defineProps(...). 

./withDefaults_typed_destructure.vue
1  |  <script setup lang="ts">
2  |  const { msg, count } = withDefaults(defineProps<{ msg?: string; count?: number }>(), { msg: 'hi', count: 1 })
   |                         ^^^^^^^^^^^^
3  |  </script>

