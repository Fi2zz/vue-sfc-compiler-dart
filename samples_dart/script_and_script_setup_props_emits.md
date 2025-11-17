# script_and_script_setup_props_emits

```
import { defineComponent as _defineComponent } from "vue";

const __default__ = {
props: {
title: String,
count: {
type: Number,
default: 0
}
},
emits: ["update", "delete"]
};
export default /*@__PURE__*/ _defineComponent({
...__default__,
props: {},
emits: ["update", "delete"],
setup(__props: any, { expose: __expose, emit: __emit }) {
__expose();

const props = __props;
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
