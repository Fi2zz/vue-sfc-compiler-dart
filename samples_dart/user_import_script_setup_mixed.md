# user_import_script_setup_mixed

```
import { defineComponent as _defineComponent } from "vue";
import {
computed,
ref,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

// 用户导入 - 混合不同类型;
const router = useRouter();
const route = useRoute();
const store = useStore();
const email = ref('');
const phone = ref('');
const isValidEmail = computed(() => validateEmail(email.value));
const isValidPhone = computed(() => validatePhone(phone.value));
const debouncedSearch = debounce((query: string) => {
store.dispatch('search', query)
}, 300);
function showMessage(message: string, type: 'success' | 'error' = 'success') {
ElMessage({
message,
type,
d;

const __returned__ = {
router,
route,
store,
email,
phone,
isValidEmail,
isValidPhone,
debouncedSearch,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
