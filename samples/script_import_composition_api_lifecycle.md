# script_import_composition_api_lifecycle

```
import { ref, onMounted, onUpdated, onUnmounted, onBeforeMount } from 'vue'

export default {
  name: 'LifecycleInScript',
  setup() {
    const message = ref('')
    
    onBeforeMount(() => {
      message.value = 'before mount'
    })
    
    onMounted(() => {
      console.log('mounted')
      message.value = 'mounted'
    })
    
    onUpdated(() => {
      console.log('updated')
    })
    
    onUnmounted(() => {
      console.log('unmounted')
    })
    
    return {
      message
    }
  }
}
```

