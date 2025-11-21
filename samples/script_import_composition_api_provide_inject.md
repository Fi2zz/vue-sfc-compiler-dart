# script_import_composition_api_provide_inject

```
import { ref, provide, inject } from 'vue'

export default {
  name: 'ProvideInjectInScript',
  setup() {
    const theme = ref('light')
    const user = inject('currentUser', ref({ name: 'Guest' }))
    
    provide('theme', theme)
    provide('appConfig', {
      version: '1.0.0',
      apiUrl: 'https://api.example.com'
    })
    
    function toggleTheme() {
      theme.value = theme.value === 'light' ? 'dark' : 'light'
    }
    
    return {
      theme,
      user,
      toggleTheme
    }
  }
}
```

