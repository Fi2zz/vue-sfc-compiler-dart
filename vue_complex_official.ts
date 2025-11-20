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
} from "vue";

import { createApp } from "vue";
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

// const $props = withDefaults(
//   defineProps<{
//     title: string;
//     count?: number;
//     items: Item[];
//     config?: { theme: "light" | "dark" };
//   }>(),
//   { items: () => [], count: 0, title: "Helloworld" }
// );

export default /*@__PURE__*/ _defineComponent({
  ...__default__,
  ...{ name: "VueComplex", inheritAttrs: false },
  props: {
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
  emits: /*@__PURE__*/ _mergeModels(
    ["increment", "select", "update:count"],
    ["update:value", "update:cheched", "update:hello", "update:modelValue"],
  ),
  setup(__props, { expose: __expose, emit: __emit }) {
    function hellow() {}

    const abc: number = 123;
    const abcd = 123,
      cde = 234;
    const $emitter = __emit;
    //@ts-ignore
    const valueModel = _useModel<number>(__props, "value");
    //@ts-ignore
    const checked = _useModel<boolean>(__props, "cheched");
    const [model, modelModifiers] = _useModel(__props, "hello");
    // defineSlots();
    _useModel(__props, "modelValue");

    const { header, default: defaultSlot = () => {}, footer } = _useSlots();
    const de = slots.default;

    const attrs = useAttrs();
    const $slots = useSlots();
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
      hellow,
      abc,
      abcd,
      cde,
      $emitter,
      valueModel,
      checked,
      model,
      modelModifiers,
      header,
      defaultSlot,
      footer,
      de,
      attrs,
      $slots,
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
