# user_import_script_setup_vue_use

```ts
import { defineComponent as _defineComponent } from 'vue'
import { useLocalStorage, useDark, useToggle, useDebounce, useThrottle } from '@vueuse/core';
import { useAxios } from '@vueuse/integrations/useAxios';
export default /*@__PURE__*/_defineComponent({  __name: 'user_import_script_setup_vue_use',
setup(__props: any, { expose: __expose }) {
  __expose();
const userPreferences = useLocalStorage('user-preferences', {
  theme: 'light',
  fontSize: 14,
  sidebarCollapsed: false
})
const isDark = useDark()
const toggleDark = useToggle(isDark)
const searchQuery = ref('')
const debouncedQuery = useDebounce(searchQuery, 500)
const throttledQuery = useThrottle(searchQuery, 1000)
const { data, error, isLoading } = useAxios('/api/users', {
  method: 'GET'
})
watch(debouncedQuery, (newQuery) => {
  console.log('搜索:', newQuery)
})
const __returned__ = { userPreferences, isDark, toggleDark, searchQuery, debouncedQuery, throttledQuery, data }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
