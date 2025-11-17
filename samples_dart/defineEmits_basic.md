# defineEmits_basic

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
emits: ["update", "remove"],
setup(__props, { expose: __expose, emit: __emit }) {
__expose();

const emit = __emit;
function onUpdate(id:number){ emit('update', id) }

const __returned__ = {
onUpdate,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
