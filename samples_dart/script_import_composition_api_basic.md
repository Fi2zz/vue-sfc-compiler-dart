# script_import_composition_api_basic

```
import { ref, computed, onMounted } from 'vue'

export default {
  name: 'CompositionInScript',
  setup() {
    const count = ref(0)
    const doubled = computed(() => count.value * 2)

    onMounted(() => {
      console.log('component mounted')
    })

    function increment() {
      count.value++
    }

    return {
      count,
      doubled,
      increment
    }
  }
}
```
