# variables_destructure

示例：

```vue
<script setup>
const { x, ok = true } = { x: 1, ok: true }
</script>
```

编译输出：

```ts
export default {
  __name: 'variables_destructure',
  setup(__props, { expose: __expose }) {
  __expose();

const { x, ok = true } = { x: 1, ok: true }

const __returned__ = { x, ok }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

