# onUnmounted_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
onUnmounted,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

onUnmounted(() => {});

const __returned__ = {
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
