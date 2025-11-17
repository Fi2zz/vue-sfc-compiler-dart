# user_import_script_setup_vue_use

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

// 用户导入 VueUse 库;
// 本地存储;
const userPreferences = useLocalStorage('user-preferences', {
theme: 'light',
fontSize: 14,
sidebarCollapsed: false
});
// 暗黑模式;
const isDark = useDark();
const toggleDark = useToggle(isDark);
// 防抖和节流;
const searchQuery = ref('');
const debouncedQuery = useDebounce(searchQuery, 500);
const throttledQuery = useThrottle(searchQuery, 1000);
// HTTP 请求;
const { data, error, isLoading } = useAxios('/api/users', {
method: 'GET'
});
watch(debouncedQuery, (newQuery;

const __returned__ = {
userPreferences,
isDark,
toggleDark,
searchQuery,
debouncedQuery,
throttledQuery,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
