# script_import_composition_api_refs

示例：

```vue
<script>
import { ref, unref, isRef, toRef, toRefs } from 'vue'

export default {
  name: 'RefsInScript',
  props: ['initialValue'],
  setup(props) {
    const count = ref(0)
    const maybeRef = ref(10)
    const rawValue = 20
    
    const fromProps = toRef(props, 'initialValue')
    
    function checkRef(value) {
      return isRef(value)
    }
    
    function getValue(value) {
      return unref(value)
    }
    
    return {
      count,
      maybeRef,
      rawValue,
      fromProps,
      checkRef,
      getValue
    }
  }
}
</script>
```

编译输出：

```ts
import { ref, unref, isRef, toRef, toRefs } from 'vue'

export default {
  name: 'RefsInScript',
  props: ['initialValue'],
  setup(props) {
    const count = ref(0)
    const maybeRef = ref(10)
    const rawValue = 20
    
    const fromProps = toRef(props, 'initialValue')
    
    function checkRef(value) {
      return isRef(value)
    }
    
    function getValue(value) {
      return unref(value)
    }
    
    return {
      count,
      maybeRef,
      rawValue,
      fromProps,
      checkRef,
      getValue
    }
  }
}
```

