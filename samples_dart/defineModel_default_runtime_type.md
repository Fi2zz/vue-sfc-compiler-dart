# defineModel_default_runtime_type

```
import { useModel as _useModel, mergeModels as _mergeModels } from "vue";

export default {
props: /*@__PURE__*/ _mergeModels({
},
{
modelValue: { type: String },
modelModifiers: {},
}),
emits: /*@__PURE__*/ _mergeModels([], ["update:modelValue"]),
setup(__props, { expose: __expose }) {
__expose();

const model = _useModel(__props, "modelValue");

const __returned__ = {
model,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
};
```
