# unref_isRef_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
isRef,
ref,
unref,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const a = ref(1);
const v = unref(a);
const ok = isRef(a);

const __returned__ = {
a,
v,
ok,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
