# script_and_script_setup_mixed_features

```
import { defineComponent as _defineComponent } from "vue";
import {
computed,
ref,
} from "vue";

const __default__ = {
name: "MixedComponent",
data() {
return {
legacyData: "legacy"
}
},
computed: {
legacyComputed() {
return this.legacyData + " computed"
}
},
methods: {
legacyMethod() {
console.log("legacy method")
}
}
};
export default /*@__PURE__*/ _defineComponent({
...__default__,
setup(__props, { expose: __expose }) {
__expose();

const setupCount = ref(0);
const setupComputed = computed(() => setupCount.value * 2);
function setupMethod() {
console.log('setup method')
}

const __returned__ = {
setupCount,
setupComputed,
setupMethod,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
