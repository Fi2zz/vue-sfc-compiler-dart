# provide_inject_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
provide,
inject,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

provide('key', 1);
const injected = inject('key', 0);

const __returned__ = {
injected,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
