# function_basic

示例：

```vue
<script setup>
function foo(){ return 1 }
</script>
```

编译输出：

```ts
export default {
  __name: 'function_basic',
  setup(__props, { expose: __expose }) {
  __expose();

function foo(){ return 1 }

const __returned__ = { foo }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

