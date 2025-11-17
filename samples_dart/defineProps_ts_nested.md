# defineProps_ts_nested

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: {
user: { type: Array, required: true },
},
setup(__props: any, { expose: __expose }) {
__expose();

const props = __props;

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
