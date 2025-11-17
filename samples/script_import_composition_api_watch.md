# script_import_composition_api_watch

```
import { ref, watch, watchEffect } from 'vue'

export default {
  name: 'WatchInScript',
  setup() {
    const count = ref(0)
    const multiplier = ref(1)
    const result = ref(0)

    watch([count, multiplier], ([newCount, newMultiplier]) => {
      result.value = newCount * newMultiplier
    })

    watchEffect(() => {
      console.log(`Current count: ${count.value}`)
    })

    function increment() {
      count.value++
    }

    function updateMultiplier(value) {
      multiplier.value = value
    }

    return {
      count,
      multiplier,
      result,
      increment,
      updateMultiplier
    }
  }
}
```
