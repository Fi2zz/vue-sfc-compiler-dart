```ts
import {
  useModel as _useModel,
  mergeModels as _mergeModels,
  defineComponent as _defineComponent,
} from "vue";
import {
  ref,
  reactive,
  computed,
  watch,
  watchEffect,
  onMounted,
  provide,
  inject,
  nextTick,
  defineAsyncComponent,
  useSlots,
  useAttrs,
} from "vue";
type Item = { id: number; label: string };

const __default__ = {
  name: "TestComplextComponent",

  data(vm) {
    return { world: "hello" };
  },
  mounted() {},
  methods: {},
};
export default /*@__PURE__*/ _defineComponent({
  ...__default__,
  ...{ name: "VueComplex", inheritAttrs: false },
  props: /*@__PURE__*/ _mergeModels(
    {
      title: { type: String, required: true },
      count: { type: Number, required: false },
      items: { type: Array, required: true, default: () => [] },
      config: { type: Object, required: false },
    },
    {
      value: { type: Number, ...{ default: 0 } },
      valueModifiers: {},
      cheched: { type: Boolean, ...{ default: false } },
      chechedModifiers: {},
      modelValue: { type: String, default: "helloworld" },
      modelModifiers: {},
    }
  ),
  emits: /*@__PURE__*/ _mergeModels(
    ["increment", "select", "update:count"],
    ["update:value", "update:cheched", "update:modelValue"]
  ),
  setup(__props: any, { expose: __expose, emit: __emit }) {
    const $props = __props;
    const myemit = __emit;
    const valueModel = _useModel<number>(__props, "value");
    const checked = _useModel<boolean>(__props, "cheched");
    const modelValue = _useModel(__props, "modelValue");
    const attrs = useAttrs();
    const slots = useSlots();
    const state = reactive({
      selectedId: null as number | null,
      loading: false,
    });
    const doubled = computed(() => (valueModel.value ?? 0) * 2);
    function increment() {
      const by = 1;
      myemit("increment", by);
      myemit("update:count", ($props.count ?? 0) + by);
    }
    function select(id: number) {
      state.selectedId = id;
      myemit("select", id);
    }
    onMounted(async () => {
      state.loading = true;
      await nextTick();
      state.loading = false;
    });
    provide("theme", $props.config?.theme ?? "light");
    const injectedTheme = inject<string>("theme", "light");
    __expose({
      focus: () => {},
      reset: () => {
        state.selectedId = null;
      },
    });
    const AsyncChild = defineAsyncComponent(async () => {
      return {
        template: "<div>Async Child</div>",
      } as any;
    });

    const __returned__ = {
      $props,
      myemit,
      valueModel,
      checked,
      modelValue,
      attrs,
      slots,
      state,
      doubled,
      increment,
      select,
      injectedTheme,
      AsyncChild,
    };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
