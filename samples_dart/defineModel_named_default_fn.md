# defineModel_named_default_fn

```
import { useModel as _useModel, mergeModels as _mergeModels, defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: /*@__PURE__*/ _mergeModels({
},
{
config: { type: Object, ...{ default: () => ({ a: 1 }) } },
configModifiers: {},
}),
emits: /*@__PURE__*/ _mergeModels([], ["update:config"]),
setup(__props, { expose: __expose }) {
__expose();

const config = _useModel<{ a: number }>(__props, 'config');

const __returned__ = {
config,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
