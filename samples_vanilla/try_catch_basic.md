# try_catch_basic

示例：

```vue
<script setup>
try { throw new Error('x') } catch (e) { } finally { }
</script>
```

编译输出：

```ts
export default {
  __name: 'try_catch_basic',
  setup(__props, { expose: __expose }) {
  __expose();

try { throw new Error('x') } catch (e) { } finally { }

const __returned__ = {  }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

