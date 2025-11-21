# script_import_composition_api_reactive

```
import { reactive, computed, watch } from 'vue'

export default {
  name: 'ReactiveInScript',
  setup() {
    const state = reactive({
      name: '',
      age: 0
    })
    
    const description = computed(() => {
      return `${state.name} is ${state.age} years old`
    })
    
    watch(() => state.age, (newAge, oldAge) => {
      console.log(`age changed from ${oldAge} to ${newAge}`)
    })
    
    function updateProfile(name, age) {
      state.name = name
      state.age = age
    }
    
    return {
      state,
      description,
      updateProfile
    }
  }
}
```

