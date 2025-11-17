# script_import_composition_api_lifecycle

示例：

```vue
<script>
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
</script>
```

编译输出：

```ts
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

