# script_and_script_setup_basic

示例：

```vue
<script>
export default {
  name: 'MyComponent',
  inheritAttrs: false
}
</script>

<script setup>
const count = ref(0)
</script>
```

编译输出：

```ts
const __default__ = {
  name: 'MyComponent',
  inheritAttrs: false
}

export default /*@__PURE__*/Object.assign(__default__, {
  setup(__props, { expose: __expose }) {
  __expose();

const count = ref(0)

const __returned__ = { count }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

