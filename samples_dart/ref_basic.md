# ref_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
ref,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const count = ref(0);

const __returned__ = {
count,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
