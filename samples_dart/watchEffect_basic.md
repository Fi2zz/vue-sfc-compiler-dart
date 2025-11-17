# watchEffect_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
ref,
watchEffect,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const v = ref(0);
watchEffect(() => { v.value });

const __returned__ = {
v,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
