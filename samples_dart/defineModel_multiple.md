# defineModel_multiple

```
import { useModel as _useModel, mergeModels as _mergeModels, defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: /*@__PURE__*/ _mergeModels({
},
{
modelValue: { type: String },
modelModifiers: {},
checked: { type: Boolean },
checkedModifiers: {},
}),
emits: /*@__PURE__*/ _mergeModels([], ["update:modelValue", "update:checked"]),
setup(__props, { expose: __expose }) {
__expose();

const title = _useModel<string>(__props, "modelValue");
const checked = _useModel<boolean>(__props, 'checked');

const __returned__ = {
title,
checked,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
