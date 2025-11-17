# user_import_script_setup_basic

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

// 用户自定义导入;
// 使用导入的功能;
const userService = new UserService();
const { user, isLoggedIn } = useAuth();
const currentDate = formatDate(new Date());
const userProfile = ref<UserProfile | null>(null);
const settings = reactive<UserSettings>({
theme: 'light',
language: 'zh-CN'
});
async function loadUserData() {
if (isLoggedIn.value) {
userProfile.value = await userService.getProfile(API_ENDPOINTS.user.pr;

const __returned__ = {
userService,
currentDate,
userProfile,
settings,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
