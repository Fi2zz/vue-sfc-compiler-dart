# user_import_script_setup_basic

```ts
import { defineComponent as _defineComponent } from 'vue'
import { formatDate } from '@/utils/format';
import { UserService } from '@/services/user';
import type { UserProfile, UserSettings } from '@/types/user';
import { useAuth } from '@/composables/useAuth';
import { API_ENDPOINTS } from '@/config/api';
export default /*@__PURE__*/_defineComponent({  __name: 'user_import_script_setup_basic',
setup(__props: any, { expose: __expose }) {
  __expose();
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
const __returned__ = { userService, user, currentDate, userProfile, settings, loadUserData }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}});
```
