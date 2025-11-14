# variables_object

示例：

```vue
<script setup>
const obj = { x: 1, ok: true }
</script>
```

编译输出：

```ts
export default {
  __name: 'variables_object',
  setup(__props, { expose: __expose }) {
  __expose();

const obj = { x: 1, ok: true }

const __returned__ = { obj }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

