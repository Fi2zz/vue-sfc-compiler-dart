# defineEmits_type_mixed_error

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
emits: ["a"],
setup(__props, { expose: __expose, emit: __emit }) {
__expose();

const emit = __emit;

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
