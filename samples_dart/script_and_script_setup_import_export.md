# script_and_script_setup_import_export

```
import { defineComponent as _defineComponent } from "vue";
import {
ref,
} from "vue";

const __default__ = {
name: "ImportExportComponent"
};
export default /*@__PURE__*/ _defineComponent({
...__default__,
setup(__props, { expose: __expose }) {
__expose();

const localValue = ref('local');

const __returned__ = {
localValue,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
