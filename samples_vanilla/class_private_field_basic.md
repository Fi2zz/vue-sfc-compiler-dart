# class_private_field_basic

示例：

```vue
<script setup>
class Y { #a = 1 }
const y = new Y()
</script>
```

编译输出：

```ts
export default {
  __name: 'class_private_field_basic',
  setup(__props, { expose: __expose }) {
  __expose();

class Y { #a = 1 }
const y = new Y()

const __returned__ = { Y, y }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

