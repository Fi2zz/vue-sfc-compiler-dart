# defineEmits_ts_union_payload

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
emits: ["select"],
setup(__props, { expose: __expose, emit: __emit }) {
__expose();

const emit = __emit;
emit('select', { id: 1 });

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
