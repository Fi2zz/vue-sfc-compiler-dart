# computed_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
computed,
ref,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const count = ref(1);
const double = computed(() => count.value * 2);

const __returned__ = {
count,
double,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
