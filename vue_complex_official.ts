import {
  useModel as _useModel,
  useSlots as _useSlots,
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
  unref as _unref,
} from "vue";

// import * as bug from "vue";
//@ts-ignore
// import vue from "vue";

export const a = 1;

import { createApp } from "vue";
//@ts-ignore
import * as vue from "vue";
//@ts-ignore
import hello from "world";
// export default {};
const __default__ = {
  name: "TestComplextComponent",
  //@ts-ignore
  data(vm) {
    return { world: "hello" };
  },
  mounted() {},
  methods: {},
};

type Item = { id: number; label: string };

// const [items = [], config = "dark"] = defineProps<{
//   title: string;
//   count?: number;
//   items: Item[];
//   config?: { theme: "light" | "dark" };
// }>();

export default /*@__PURE__*/ _defineComponent({
  ...__default__,
  ...{ name: "VueComplex", inheritAttrs: false },
  props: /*@__PURE__*/ _mergeModels(
    {
      title: { type: String, required: true, default: "Helloworld" },
      count: { type: Number, required: false, default: 0 },
      items: { type: Array, required: true, default: () => [] },
      config: { type: Object, required: false },
    },
    {
      value: { type: Number, ...{ default: 0 } },
      valueModifiers: {},
      cheched: { type: Boolean, ...{ default: false } },
      chechedModifiers: {},
      hello: {
        type: String,
        default: "helloworld",
      },
      helloModifiers: {},
      modelValue: {},
      modelModifiers: {},
    },
  ),
  emits: /*@__PURE__*/ _mergeModels(
    ["increment", "select", "update:count"],
    ["update:value", "update:cheched", "update:hello", "update:modelValue"],
  ),
  setup(__props: any, { expose: __expose, emit: __emit }) {
    function hellow() {}

    const world = () => {};
    const world2 = function () {};
    const world3 = function named() {};
    // export { hellow };

    const abc: number = 123;
    const abcd = 123,
      cde = 234;
    const $props = __props;

    const $emitter = __emit;
    //@ts-ignore
    const valueModel = _useModel<number>(__props, "value");
    //@ts-ignore
    const checked = _useModel<boolean>(__props, "cheched");
    const [model, modelModifiers] = _useModel(__props, "hello");
    // defineSlots();
    _useModel(__props, "modelValue");

    const { header, default: defaultSlot = () => {}, footer } = _useSlots();

    const attrs = useAttrs();
    const $slots = useSlots();
    const de = $slots.default;
    const state = reactive({
      selectedId: null as number | null,
      loading: false,
    });
    const doubled = computed(() => (valueModel.value ?? 0) * 2);
    function onIncrement() {
      const by = 1;
      $emitter("increment", by);
      $emitter("update:count", ($props.count ?? 0) + by);
    }
    function onSelect(id: number) {
      state.selectedId = id;
      $emitter("select", id);
    }
    onMounted(async () => {
      state.loading = true;
      await nextTick();
      state.loading = false;
    });
    provide("theme", $props.config?.theme ?? "light");
    const injectedTheme = inject<string>("theme", "light");
    // defineExpose({
    //   focus: () => {},
    //   reset: () => {
    //     state.selectedId = null;
    //   },
    // });

    __expose();
    const AsyncChild = defineAsyncComponent(async () => {
      return {
        template: "<div>Async Child</div>",
      } as any;
    });

    const __returned__ = {
      a,
      hellow,
      world,
      world2,
      world3,
      abc,
      abcd,
      cde,
      $props,
      $emitter,
      valueModel,
      checked,
      model,
      modelModifiers,
      header,
      defaultSlot,
      footer,
      attrs,
      $slots,
      de,
      state,
      doubled,
      onIncrement,
      onSelect,
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
