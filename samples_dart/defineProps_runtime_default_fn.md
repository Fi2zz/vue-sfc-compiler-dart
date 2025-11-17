# defineProps_runtime_default_fn

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: { items: { type: Array, default: ()=> [] } },
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
