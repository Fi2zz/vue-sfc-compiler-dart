# script_multiple_export_default_ts_generic_error

```
import { ref, Ref } from 'vue'

function createComponent<T>(name: string, initialValue: T) {
  return {
    name,
    setup() {
      const value: Ref<T> = ref(initialValue)
      return { value }
    }
  }
}

export default createComponent('GenericComponent1', 'hello')
export default createComponent('GenericComponent2', 42)
```
