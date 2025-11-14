# console_basic

示例：

```vue
<script setup>
console.log('hello')
</script>
```

编译输出：

```ts
export default {
  __name: 'console_basic',
  setup(__props, { expose: __expose }) {
  __expose();

console.log('hello')

const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

