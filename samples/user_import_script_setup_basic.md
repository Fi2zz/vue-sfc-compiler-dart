# user_import_script_setup_basic

```
import { defineComponent as _defineComponent } from 'vue'
import { formatDate } from '@/utils/format'
import { UserService } from '@/services/user'
import type { UserProfile, UserSettings } from '@/types/user'
import { useAuth } from '@/composables/useAuth'
import { API_ENDPOINTS } from '@/config/api'

// 使用导入的功能

export default /*@__PURE__*/_defineComponent({
  __name: 'user_import_script_setup_basic',
  setup(__props, { expose: __expose }) {
  __expose();

// 用户自定义导入
const userService = new UserService()
const { user, isLoggedIn } = useAuth()
const currentDate = formatDate(new Date())

const userProfile = ref<UserProfile | null>(null)
const settings = reactive<UserSettings>({
  theme: 'light',
  language: 'zh-CN'
})

async function loadUserData() {
  if (isLoggedIn.value) {
    userProfile.value = await userService.getProfile(API_ENDPOINTS.user.profile)
  }
}

loadUserData()

const __returned__ = { userService, user, isLoggedIn, currentDate, userProfile, settings, loadUserData, get formatDate() { return formatDate }, get UserService() { return UserService }, get useAuth() { return useAuth }, get API_ENDPOINTS() { return API_ENDPOINTS } }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```
