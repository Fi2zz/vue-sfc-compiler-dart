# getCurrentInstance_emit_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
getCurrentInstance,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const inst = getCurrentInstance();
inst?.emit?.('change');

const __returned__ = {
inst,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
