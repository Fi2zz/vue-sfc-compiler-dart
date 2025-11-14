# class_basic

示例：

```vue
<script setup>
class X { a = 1 }
const x = new X()
</script>
```

编译输出：

```ts
export default {
  __name: 'class_basic',
  setup(__props, { expose: __expose }) {
  __expose();

class X { a = 1 }
const x = new X()

const __returned__ = { X, x }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

