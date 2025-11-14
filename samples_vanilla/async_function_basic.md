# async_function_basic

示例：

```vue
<script setup>
async function load(){ return 1 }
</script>
```

编译输出：

```ts
export default {
  __name: 'async_function_basic',
  setup(__props, { expose: __expose }) {
  __expose();

async function load(){ return 1 }

const __returned__ = { load }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

