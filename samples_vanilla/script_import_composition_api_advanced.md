# script_import_composition_api_advanced

示例：

```vue
<script>
import { ref, computed, watch, nextTick, getCurrentInstance } from 'vue'

export default {
  name: 'AdvancedCompositionInScript',
  setup() {
    const count = ref(0)
    const instance = getCurrentInstance()
    
    const doubleCount = computed(() => count.value * 2)
    
    const tripleCount = computed({
      get: () => count.value * 3,
      set: (val) => {
        count.value = Math.floor(val / 3)
      }
    })
    
    async function incrementAndWait() {
      count.value++
      await nextTick()
      console.log('DOM updated')
    }
    
    watch(count, (newVal, oldVal) => {
      console.log(`Count changed: ${oldVal} -> ${newVal}`)
    })
    
    return {
      count,
      doubleCount,
      tripleCount,
      incrementAndWait,
      instance
    }
  }
}
</script>
```

编译输出：

```ts
import { ref, computed, watch, nextTick, getCurrentInstance } from 'vue'

export default {
  name: 'AdvancedCompositionInScript',
  setup() {
    const count = ref(0)
    const instance = getCurrentInstance()
    
    const doubleCount = computed(() => count.value * 2)
    
    const tripleCount = computed({
      get: () => count.value * 3,
      set: (val) => {
        count.value = Math.floor(val / 3)
      }
    })
    
    async function incrementAndWait() {
      count.value++
      await nextTick()
      console.log('DOM updated')
    }
    
    watch(count, (newVal, oldVal) => {
      console.log(`Count changed: ${oldVal} -> ${newVal}`)
    })
    
    return {
      count,
      doubleCount,
      tripleCount,
      incrementAndWait,
      instance
    }
  }
}
```

