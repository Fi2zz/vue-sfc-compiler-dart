# defineProps_runtime_array

示例：

```vue
<script setup>
const props = defineProps(['msg','count'])
</script>
```

编译输出：

```ts
export default {
  __name: 'defineProps_runtime_array',
  props: ['msg','count'],
  setup(__props, { expose: __expose }) {
  __expose();

const props = __props

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

