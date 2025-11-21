# user_import_script_setup_mixed

```
import { defineComponent as _defineComponent } from 'vue'
import { ref, computed } from 'vue'
import { debounce } from 'lodash-es'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '@/store'
import { validateEmail, validatePhone } from '@/utils/validation'
import { ElMessage } from 'element-plus'
import type { FormRules, FormInstance } from 'element-plus'


export default /*@__PURE__*/_defineComponent({
  __name: 'user_import_script_setup_mixed',
  setup(__props, { expose: __expose }) {
  __expose();

// 用户导入 - 混合不同类型
const router = useRouter()
const route = useRoute()
const store = useStore()

const email = ref('')
const phone = ref('')

const isValidEmail = computed(() => validateEmail(email.value))
const isValidPhone = computed(() => validatePhone(phone.value))

const debouncedSearch = debounce((query: string) => {
  store.dispatch('search', query)
}, 300)

function showMessage(message: string, type: 'success' | 'error' = 'success') {
  ElMessage({
    message,
    type,
    duration: 3000
  })
}

const __returned__ = { router, route, store, email, phone, isValidEmail, isValidPhone, debouncedSearch, showMessage, ref, computed, get debounce() { return debounce }, get useRouter() { return useRouter }, get useRoute() { return useRoute }, get useStore() { return useStore }, get validateEmail() { return validateEmail }, get validatePhone() { return validatePhone }, get ElMessage() { return ElMessage } }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

